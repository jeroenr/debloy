[![endorse](http://api.coderwall.com/jeroenr/endorsecount.png)](http://coderwall.com/jeroenr)

# debloy

debloy is a capistrano plugin to facilitate the deployment of debian packages (inspired by supply_drop). It works by simply copying (using rsync, or scp) your debian packages to your servers and installing them through the package manager

### Installation

    gem install debloy

or with Bundler

    gem 'debloy'

### Tasks

    cap debloy:bootstrap

This sets up the environment for dpkg or apt deployment, depending on your configuration.

    cap debloy

This deploys the debian packages on the target servers.

    cap debloy:teardown

Cleans up the environment.

### Configuration

At the top of your deploy.rb

    require 'rubygems'
    require 'debloy'

then optionally set some variables

    set :debian_source, '.'

the directory containing your debian packages that will be rsynced to the servers.

  	set :debian_target, '/tmp'

the temp directory on the target machine to hold the packages before installing.

 	set :debian_package_manager, 'dpkg'

the debian package manager to use (one of [dpkg, apt]).

  	set :debian_stream_log, false

determines whether to stream the command output.
	
	set :debian_filter, '*'

a glob syntax filter to determine which packages to deploy. By default all will be deployed.