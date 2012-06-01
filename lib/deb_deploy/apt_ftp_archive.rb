module DebDeploy
  class AptFtpArchive
    class << self
      def command(arguments, options={})
        "apt-ftparchive " << options.map{|k,v| "-o #{k}='#{v}'"}.join(' ') << " #{arguments}"
      end

      def create_packages_file(from, options={})
        command("packages #{from} | gzip -9c > Packages.gz", options)
      end

      def create_release_file(from, options={})
        release_file_options = {
              "Codename" => "deb_deploy", 
              "Components" => "deb_deploy", 
              "Origin" => "deb_deploy", 
              "Label" => "Deployed with deb_deploy", 
              "Architectures" => "all", 
              "Suite" => "stable"
            }
        command("release #{from} > Release", options.merge(Hash[release_file_options.map {|k,v| ["APT::FTPArchive::Release::#{k}",v]}]))
      end


    end
  end
end
