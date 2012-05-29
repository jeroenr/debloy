require 'deb_deploy/rsync'
require 'deb_deploy/logger/batch'
require 'deb_deploy/logger/stream'
require 'deb_deploy/util/parallel_enumerable'

Capistrano::Configuration.instance.load do
  namespace :deb do
  	set :debian_source, '.'
  	set :debian_target, '/tmp'
  	set :debian_package_manager, 'dpkg'
  	set :debian_stream_log, false
    set :debian_filter, '*'

    repository_root_dir = "#{debian_target}/deb_deploy"

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
        run "mkdir -p #{repository_root_dir}"
        sudo "apt-get update"
        sudo "apt-get install -y rsync"
        logger.debug "Dependencies installed"
      end

      desc "creates local debian repository for apt-get"
      task :apt do
        run "mkdir -p #{repository_root_dir}"

        sudo "apt-get update"
        sudo "apt-get install -y rsync dpkg-dev gzip"

        logger.debug "Dependencies installed"

        put "deb file:#{repository_root_dir} ./", "#{debian_target}/deb_deploy.list"

        put "Package: *\nPin: origin\nPin-Priority: 900\n", "#{debian_target}/00debdeploy"

        run "cd #{repository_root_dir} && apt-ftparchive packages .  | gzip -9c > Packages.gz"

        logger.debug "Set up local debian repository"
      end
      
    end

    namespace :teardown do
      desc "cleans up deb_deploy directory (#{repository_root_dir})"
      task :default do
        run "rm -rf #{repository_root_dir}"
        run "rm -f #{debian_target}/deb_deploy.list"
        run "rm -f #{debian_target}/00debdeploy"
        logger.debug "Removed deployment directory"
      end
    end

  	desc "copies debian packages to the server"
  	task :copy_packages do
  		targets = find_servers_for_task(current_task)
  		failed_targets = targets.async.map do |target|
  			copy_cmd = DebDeploy::Rsync.command(
  				debian_source,
  				DebDeploy::Rsync.remote_address(target.user || fetch(:user, ENV['USER']), target.host, repository_root_dir),
          :filter => ['*/'] + debian_filter.split(',').map {|x| "#{x}.deb"},
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
    	      sudo "dpkg -R -i #{repository_root_dir}" do |channel, stream, data|
    	        log.collect(channel[:host], data)
    	      end
          when "apt"
            run "cd #{repository_root_dir} && apt-ftparchive packages .  | gzip -9c > Packages.gz"

            release_file_options = {
              "Codename" => "deb_deploy", 
              "Components" => "deb_deploy", 
              "Origin" => "deb_deploy", 
              "Label" => "Deployed with deb_deploy", 
              "Architectures" => "all", 
              "Suite" => "stable"
            }

            run "cd #{repository_root_dir} && apt-ftparchive " << release_file_options.map{|k,v| "-o APT::FTPArchive::Release::#{k}='#{v}'"}.join(' ') << " release . > Release"

            sudo "apt-get -o Dir::Etc::SourceList=#{debian_target}/deb_deploy.list -o Dir::Etc::Preferences=#{debian_target}/00debdeploy update"

            list_packages_cmd = "zcat #{repository_root_dir}/Packages.gz | grep Package | cut -d ' ' -f2 | sed ':a;N;$!ba;s/\n/ /g'"
            
            run "#{list_packages_cmd} | xargs #{sudo} apt-get -y --allow-unauthenticated -o Dir::Etc::SourceList=#{debian_target}/deb_deploy.list -o Dir::Etc::Preferences=#{debian_target}/00debdeploy install" do |channel, stream, data|
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
