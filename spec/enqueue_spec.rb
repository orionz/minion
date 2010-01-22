require File.dirname(__FILE__) + '/base'

describe Minion do
	it "should throw an exception when passed a nil queue" do
		lambda { Minion.enqueue(nil, {}) }.should.raise(RuntimeError)
	end
	it "should throw an exception when passed an empty queue" do
		lambda { Minion.enqueue([], {}) }.should.raise(RuntimeError)
  end
end
