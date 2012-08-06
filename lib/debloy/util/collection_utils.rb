module Debloy
  module LazyEnumerable
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
end