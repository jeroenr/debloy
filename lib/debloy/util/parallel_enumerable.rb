require 'debloy/util/collection_utils'

module Enumerable
	def async
		self.clone.extend Debloy::LazyEnumerable
	end
end
	
