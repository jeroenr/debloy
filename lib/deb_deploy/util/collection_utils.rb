module DebDeploy
  module AsynchronousCollection
    def each(&block)
      threads = []
      super do |item|
        threads << Thread.new { block.call(item) }
      end
      threads.each(&:join)
    end

    def map(&block)
      super do |item|
        Thread.new { Thread.current[:output] = block.call(item) }
      end.map(&:join).map { |t| t[:output] }
    end
  end

  module CollectionUtils
    def self.async(synced_collection)
      asynced_collection = synced_collection.clone
    end

    def self.async!(synced_collection)

    end

    private def self.convert_to_async_collection(collection)
      collection.extend DebDeploy:AsynchronousCollection
      collection
    end
  end
end