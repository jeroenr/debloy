module Debloy
  class Scp
    class << self
      def command(from, to, options={})
        flags = ['-q']
        flags << '-r' if options[:recurse]
        flags << ssh_options(options[:ssh]) if options.has_key?(:ssh)

        "scp #{flags.compact.join(' ')} #{from} #{to}"
      end

      def remote_address(user, host, path)
        user_with_host = [user, host].compact.join('@')
        [user_with_host, path].join(':')
      end

      def ssh_options(options)
        %[-o "#{options.join(' ')}"] unless options.empty?
      end
    end
  end
end