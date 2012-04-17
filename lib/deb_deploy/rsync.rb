module DebDeploy
  class Rsync
    class << self
      def command(from, to, options={})
        flags = ['-az']
        flags << '--delete'
        flags << includes(["*.deb"])
        flags << excludes(["*","*/"])
        flags << ssh_options(options[:ssh]) if options.has_key?(:ssh)

        "rsync #{flags.compact.join(' ')} #{from} #{to}"
      end

      def remote_address(user, host, path)
        user_with_host = [user, host].compact.join('@')
        [user_with_host, path].join(':')
      end

      def excludes(patterns)
        patterns.map { |p| "--exclude=#{p}" }
      end


      def includes(patterns)
        patterns.flatten.map { |p| "--include=#{p}" }
      end

      def ssh_options(options)
        mapped_options = options.map do |key, value|
          next unless value

          case key
          when :keys then [value].flatten.select { |k| File.exist?(k) }.map { |k| "-i #{k}" }
          when :config then "-F #{value}"
          when :port then "-p #{value}"
          end
        end.compact

        %[-e "ssh #{mapped_options.join(' ')}"] unless mapped_options.empty?
      end
    end
  end
end