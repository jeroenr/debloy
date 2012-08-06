require 'debloy/rsync'
require 'debloy/apt_get'
require 'debloy/apt_ftp_archive'
require 'debloy/logger/batch'
require 'debloy/logger/stream'
require 'debloy/util/parallel_enumerable'

Capistrano::Configuration.instance.load do
  namespace :debloy do
  	set :debian_source, '.'
  	set :debian_target, '/tmp'
  	set :debian_package_manager, 'dpkg'
  	set :debian_stream_log, false
    set :debian_filter, '*'

    RELEASE_FILE_OPTIONS = {
              "Codename" => "debloy",
              "Components" => "debloy",
              "Origin" => "debloy",
              "Label" => "Debloyed",
              "Architectures" => "all", 
              "Suite" => "stable"
            }

    namespace :bootstrap do
      desc "prepares remote hosts for debloyment based on selected package manager (dpkg or apt)"
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
        run "mkdir -p #{debian_target}/debloy"
        sudo Debloy::AptGet.update_cache
        sudo Debloy::AptGet.install_packages(%w(rsync))
        logger.debug "Dependencies installed"
      end

      desc "creates local debian repository for apt-get"
      task :apt do
        run "mkdir -p #{debian_target}/debloy"

        sudo Debloy::AptGet.update_cache
        sudo Debloy::AptGet.install_packages(%w(rsync dpkg-dev gzip))

        logger.debug "Dependencies installed"

        put "deb file:#{debian_target}/debloy ./", "#{debian_target}/debloy.list"

        run "cd #{debian_target}/debloy && " << Debloy::AptFtpArchive.create_packages_file('.')

        logger.debug "Set up local debian repository"
      end
      
    end

    namespace :teardown do
      desc "cleans up debloy files"
      task :default do
        sudo "rm -rf #{debian_target}/debloy"

        debloy_files = %w(/etc/apt/sources.list.d/debloy.list /etc/apt/preferences.d/00debloy) << "#{debian_target}/debloy.list" << "#{debian_target}/00debloy"
        debloy_files.each do |file_name|
          sudo "rm -f #{file_name}"
        end
        logger.debug "Removed deployment directory"
      end
    end

  	desc "copies debian packages to the server"
  	task :copy_packages do
  		targets = find_servers_for_task(current_task)
  		failed_targets = targets.async.map do |target|
  			copy_cmd = Debloy::Rsync.command(
  				debian_source,
  				Debloy::Rsync.remote_address(target.user || fetch(:user, ENV['USER']), target.host, "#{debian_target}/debloy"),
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
		      Debloy::Logger::Stream.new(logger)
	      else 
		      Debloy::Logger::Batch.new(logger)
	      end

	    begin
        case debian_package_manager
          when "dpkg"
    	      sudo "dpkg -R -i #{debian_target}/debloy" do |channel, stream, data|
    	        log.collect(channel[:host], data)
    	      end
          when "apt"
            apt_get_options = {
              "Dir::Etc::SourceList" => "#{debian_target}/debloy.list"
            }

            list_packages_cmd = "zcat #{debian_target}/debloy/Packages.gz | grep Package | cut -d ' ' -f2 | sed ':a;N;$!ba;s/\n/ /g'"

            run "cd #{debian_target}/debloy && " << Debloy::AptFtpArchive.create_packages_file('.')
            run "cd #{debian_target}/debloy && " << Debloy::AptFtpArchive.create_release_file('.', Hash[RELEASE_FILE_OPTIONS.map {|k,v| ["APT::FTPArchive::Release::#{k}",v]}])

            sudo Debloy::AptGet.update_cache(apt_get_options)

            run "#{list_packages_cmd} | xargs #{sudo} #{Debloy::AptGet.install_packages([],apt_get_options)}" do |channel, stream, data|
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
  	task :default do
  		copy_packages
  		install_packages
  	end
  end
end
