require "spec_helper"

describe Minion do

  describe ".enqueue" do

    context "when provided a nil queue" do

      it "raises an error" do
        expect { Minion.enqueue(nil, {}) }.to raise_error(RuntimeError)
      end
    end

    context "when passed an empty queue" do

      it "raises an error" do
        expect { Minion.enqueue([], {}) }.to raise_error(RuntimeError)
      end
    end
  end
end
