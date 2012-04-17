module DebDeploy
  module Logger
    class Batch
      def initialize(logger)
        @messages = {}
        @logger = logger
      end

      def collect(host, data)
        @messages[host] ||= ""
        @messages[host] << data
      end

      def collected
        @messages.keys.sort.each do |host|
          @logger.info "Log for #{host}"
          @logger.debug @messages[host], host
        end
      end
    end
  end
end