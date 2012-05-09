require 'deb_deploy/util/collection_utils'

module CoreExt
	module Enumerable
		module Parallellization
			def async
				self.clone.extend DebDeploy:AsynchronousCollection
			end
		end
	end
end
Enumerable.send :retroactively_include, CoreExt::Enumerable::Parallellization
