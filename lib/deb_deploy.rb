require 'deb_deploy/scp'
require 'deb_deploy/logger/batch'
require 'deb_deploy/logger/stream'

Capistrano::Configuration.instance.load do
  namespace :deb do
  	set :debian_source, '.'
  	set :debian_target, '/tmp/deb_deploy'
  	set :debian_package_manager, 'dpkg'
  	set :debian_stream_log, false

  	desc "copies debian packages to the server"
  	task :copy_packages do
  		targets = find_servers_for_task(current_task)
  		failed_targets = targets.map do |target|
  			copy_cmd = DebDeploy::Rsync.command(
  				debian_source,
  				DebDeploy::Rsync.remote_address(server.user || fetch(:user, ENV['USER']), server.host, debian_target),
  				:ssh => { 
  					:keys => ssh_options[:keys], 
  					:config => ssh_options[:config], 
  					:port => fetch(:port, nil) 
  				}
  			)
  			logger.debug copy_cmd
  			server.host unless system copy_cmd
  		end.compact

  		raise "rsync failed on #{failed_targets.join(',')}" if failed_targets.any?
    end

    task :install_packages do
    	log = if debian_stream_log DebDeploy::Logger::Stream.new(logger) else DebDeploy::Logger::Batch.new(logger) end

	    begin
	      run "#{sudo} #{debian_package_manager} -R -i #{debian_target}" do |channel, stream, data|
	        log.collect(channel[:host], data)
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