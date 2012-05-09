require 'deb_deploy/util/collection_utils'

module Enumerable
	def async
		self.clone.extend DebDeploy::LazyEnumerable
	end
end
	
