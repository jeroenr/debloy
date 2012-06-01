require 'deb_deploy/rsync'
require 'deb_deploy/apt_get'
require 'deb_deploy/apt_ftp_archive'
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

    RELEASE_FILE_OPTIONS = {
              "Codename" => "deb_deploy", 
              "Components" => "deb_deploy", 
              "Origin" => "deb_deploy", 
              "Label" => "Deployed with deb_deploy", 
              "Architectures" => "all", 
              "Suite" => "stable"
            }

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
        run "mkdir -p #{debian_target}/deb_deploy"
        sudo DebDeploy::AptGet.update_cache
        sudo DebDeploy::AptGet.install_packages(%w(rsync))
        logger.debug "Dependencies installed"
      end

      desc "creates local debian repository for apt-get"
      task :apt do
        run "mkdir -p #{debian_target}/deb_deploy"

        sudo DebDeploy::AptGet.update_cache
        sudo DebDeploy::AptGet.install_packages(%w(rsync dpkg-dev gzip))

        logger.debug "Dependencies installed"

        put "deb file:#{debian_target}/deb_deploy ./", "#{debian_target}/deb_deploy.list"

        put "Package: *\nPin: origin\nPin-Priority: 900\n", "#{debian_target}/00debdeploy"

        run "cd #{debian_target}/deb_deploy && " << DebDeploy::AptFtpArchive.create_packages_file('.')

        logger.debug "Set up local debian repository"
      end
      
    end

    namespace :teardown do
      desc "cleans up deb_deploy files"
      task :default do
        sudo "rm -rf #{debian_target}/deb_deploy"

        deb_deploy_files = %w(/etc/apt/sources.list.d/deb_deploy.list /etc/apt/preferences.d/00debdeploy) << "#{debian_target}/deb_deploy.list" << "#{debian_target}/00debdeploy"
        deb_deploy_files.each do |file_name|
          sudo "rm -f #{file_name}"
        end
        logger.debug "Removed deployment directory"
      end
    end

  	desc "copies debian packages to the server"
  	task :copy_packages do
  		targets = find_servers_for_task(current_task)
  		failed_targets = targets.async.map do |target|
  			copy_cmd = DebDeploy::Rsync.command(
  				debian_source,
  				DebDeploy::Rsync.remote_address(target.user || fetch(:user, ENV['USER']), target.host, "#{debian_target}/deb_deploy"),
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
    	      sudo "dpkg -R -i #{debian_target}/deb_deploy" do |channel, stream, data|
    	        log.collect(channel[:host], data)
    	      end
          when "apt"
            apt_get_options = {
              "Dir::Etc::SourceList" => "#{debian_target}/deb_deploy.list",
              "Dir::Etc::Preferences" => "#{debian_target}/00debdeploy"
            }

            list_packages_cmd = "zcat #{debian_target}/deb_deploy/Packages.gz | grep Package | cut -d ' ' -f2 | sed ':a;N;$!ba;s/\n/ /g'"

            run "cd #{debian_target}/deb_deploy && " << DebDeploy::AptFtpArchive.create_packages_file('.')
            run "cd #{debian_target}/deb_deploy && " << DebDeploy::AptFtpArchive.create_release_file('.', Hash[RELEASE_FILE_OPTIONS.map {|k,v| ["APT::FTPArchive::Release::#{k}",v]}])

            sudo DebDeploy::AptGet.update_cache(apt_get_options)

            run "#{list_packages_cmd} | xargs #{sudo} #{DebDeploy::AptGet.install_packages([],apt_get_options)}" do |channel, stream, data|
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
