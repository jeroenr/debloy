require 'deb_deploy/rsync'
require 'deb_deploy/logger/batch'
require 'deb_deploy/logger/stream'

Capistrano::Configuration.instance.load do
  namespace :deb do
  	set :debian_source, '.'
  	set :debian_target, '/tmp/deb_deploy'
  	set :debian_package_manager, 'dpkg'
  	set :debian_stream_log, false

    namespace :bootstrap do
      desc "creates directories and installs dependencies"
      task :dpkg do
        run "mkdir -p #{debian_target}"
        sudo "apt-get update"
        sudo "apt-get install -y rsync"
        logger.debug "Dependencies installed"
      end

      desc "creates local debian repository for apt-get"
      task :apt do
        run "mkdir -p #{debian_target}"

        sudo "apt-get update"
        sudo "apt-get install -y rsync dpkg-dev gzip"

        logger.debug "Dependencies installed"

        run "echo 'deb file:#{debian_target} ./' > #{debian_target}/deb_deploy.list"
        sudo "mv #{debian_target}/deb_deploy.list /etc/apt/sources.list.d/deb_deploy.list"

        logger.debug "Set up local debian repository"
      end
      
    end

  	desc "copies debian packages to the server"
  	task :copy_packages do
  		targets = find_servers_for_task(current_task)
  		failed_targets = targets.map do |target|
  			copy_cmd = DebDeploy::Rsync.command(
  				debian_source,
  				DebDeploy::Rsync.remote_address(target.user || fetch(:user, ENV['USER']), target.host, debian_target),
  				:ssh => { 
  					:keys => ssh_options[:keys], 
  					:config => ssh_options[:config], 
  					:port => fetch(:port, nil) 
  				}
  			)
  			logger.debug copy_cmd
  			target.host unless system copy_cmd
  		end.compact

  		raise "rsync failed on #{failed_targets.join(',')}" if failed_targets.any?
    end

    task :install_packages do
    	log = if debian_stream_log 
		DebDeploy::Logger::Stream.new(logger) 
	      else 
		DebDeploy::Logger::Batch.new(logger) 
	      end

	    begin
        list_packages_cmd = "zcat #{debian_target}/Packages.gz | grep Package | cut -d ' ' -f2 | sed ':a;N;$!ba;s/\n/ /g'"
        case debian_package_manager
          when "dpkg"
    	      sudo "dpkg -R -i #{debian_target}" do |channel, stream, data|
    	        log.collect(channel[:host], data)
    	      end
          when "apt"
            sudo "dpkg-scanpackages #{debian_target} /dev/null | gzip -9c > #{debian_target}/Packages.gz"
            sudo "apt-get update"

            run "#{list_packages_cmd} | xargs #{sudo} apt-get -y --allow-unauthenticated install" do |channel, stream, data|
              log.collect(channel[:host], data)
            end
          else
            raise "#{debian_package_manager} is an unsupported package manager. Only dpkg and apt are supported"
        end
          
	      logger.debug "Package installation complete."
	    ensure
	      log.collected
	    end
    end

  	desc "copies and installs debian packages to the server"
  	task :deploy do
  		copy_packages
  		install_packages
  	end
  end
end
