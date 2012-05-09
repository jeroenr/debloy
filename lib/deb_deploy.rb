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
      desc "prepares remote hosts for debian deployment based on selected package manager (dpkg or apt)"
      task :default do
        case debian_package_manager
          when "dpkg"
		        dpkg
          when "apt"
		        apt
          else
            raise "#{debian_package_manager} is an unsupported package manager. Only dpkg and apt are supported"
        end
      end
     
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

        put "deb file:#{debian_target} ./", "#{debian_target}/deb_deploy.list"
        sudo "mv #{debian_target}/deb_deploy.list /etc/apt/sources.list.d/deb_deploy.list"

        put "Package: *\nPin: origin\nPin-Priority: 900\n", "#{debian_target}/00debdeploy"
        sudo "mv #{debian_target}/00debdeploy /etc/apt/preferences.d/00debdeploy"

        run "cd #{debian_target} && apt-ftparchive packages .  | gzip -9c > Packages.gz"

        logger.debug "Set up local debian repository"
      end
      
    end

    namespace :teardown do
      desc "cleans up deb_deploy files from remote hosts based on selected package manager (dpkg or apt)"
      task :default do
        case debian_package_manager
          when "dpkg"
            dpkg
          when "apt"
            apt
          else
            raise "#{debian_package_manager} is an unsupported package manager. Only dpkg and apt are supported"
        end
      end
     
      desc "cleans up deb_deploy directory"
      task :dpkg do
        run "rm -rf #{debian_target}"
        logger.debug "Removed deployment directory"
      end

      desc "cleans up deb_deploy directory and local debian repository from remote hosts"
      task :apt do
        run "rm -rf #{debian_target}"

        sudo "rm /etc/apt/sources.list.d/deb_deploy.list"

        sudo "rm /etc/apt/preferences.d/00debdeploy"

        logger.debug "Removed local debian repository and deployment directory"
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
        case debian_package_manager
          when "dpkg"
    	      sudo "dpkg -R -i #{debian_target}" do |channel, stream, data|
    	        log.collect(channel[:host], data)
    	      end
          when "apt"
            run "cd #{debian_target} && apt-ftparchive packages .  | gzip -9c > Packages.gz"

            release_file_options = {
              "Codename" => "deb_deploy", 
              "Components" => "deb_deploy", 
              "Origin" => "deb_deploy", 
              "Label" => "Deployed with deb_deploy", 
              "Architectures" => "all", 
              "Suite" => "stable"
            }

            run "cd #{debian_target} && apt-ftparchive " << release_file_options.map{|k,v| "-o APT::FTPArchive::Release::#{k}='#{v}'"}.join(' ') << " release . > Release"

            sudo "apt-get update"

            list_packages_cmd = "zcat #{debian_target}/Packages.gz | grep Package | cut -d ' ' -f2 | sed ':a;N;$!ba;s/\n/ /g'"
            
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
