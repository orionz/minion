require File.dirname(__FILE__) + '/../lib/minion'

require 'bacon'
require 'mocha/standalone'
require 'mocha/object'

class Bacon::Context
	include Mocha::API

	def initialize(name, &block)
		@name = name
		@before, @after = [
			[lambda { mocha_setup }],
			[lambda { mocha_verify ; mocha_teardown }]
		]
		@block = block
	end

	def xit(desc, &bk)
	end
end
