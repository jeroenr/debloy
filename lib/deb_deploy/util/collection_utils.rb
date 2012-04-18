module DebDeploy
  module AsynchronousCollection
    def each(&block)
      threads = []
      super do |item|
        threads << Thread.new { yield item }
      end
      threads.each(&:join)
    end

    def map(&block)
      super do |item|
        Thread.new { Thread.current[:output] = block[item] }
      end.map(&:join).map { |thread| thread[:output] }
    end
  end

  module CollectionUtils
    def self.async(synchronous_collection)
      CollectionUtils.convert_to_async_collection(synchronous_collection.clone)
    end

    def self.async!(synchronous_collection)
      CollectionUtils.convert_to_async_collection(synchronous_collection)
    end

    private def self.convert_to_async_collection(collection)
      collection.extend DebDeploy:AsynchronousCollection
      collection
    end
  end
end