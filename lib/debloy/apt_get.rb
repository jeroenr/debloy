module Debloy
  class AptGet
    class << self
      def command(arguments, options={})
        "apt-get -y --allow-unauthenticated " << options.map{|k,v| "-o #{k}='#{v}'"}.join(' ') << " #{arguments}"
      end

      def update_cache(options={})
        command("update", options)
      end

      def install_packages(packages, options={})
        command("install #{packages.join(' ')}", options)
      end
    end
  end
end
