module Debloy
  module Logger
    class Stream
      def initialize(logger)
        @logger = logger
      end

      def collect(host, data)
        @logger.debug data, host
      end

      def collected
      end
    end
  end
end