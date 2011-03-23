require "spec_helper"

describe Minion do

  let(:bunny) do
    Minion.send(:bunny)
  end

  before(:all) do
    Minion.logger {}
  end

  describe ".enqueue" do

    let(:queue) do
      bunny.queue("minion.test")
    end

    before do
      queue.purge
    end

    context "when provided a string" do

      context "when no data is provided" do

        before do
          Minion.enqueue("minion.test")
        end

        let(:message) do
          JSON.parse(queue.pop[:payload])
        end

        it "adds empty json to the queue" do
          message.should == {}
        end
      end

      context "when nil data is provided" do

        before do
          Minion.enqueue("minion.test", nil)
        end

        let(:message) do
          JSON.parse(queue.pop[:payload])
        end

        it "adds empty json to the queue" do
          message.should == {}
        end
      end

      context "when data is provided" do

        let(:data) do
          { "field" => "value" }
        end

        before do
          Minion.enqueue("minion.test", data)
        end

        let(:message) do
          JSON.parse(queue.pop[:payload])
        end

        it "adds the json to the queue" do
          message.should == data
        end
      end
    end

    context "when provided a nil queue" do

      it "raises an error" do
        expect { Minion.enqueue(nil, {}) }.to raise_error(RuntimeError)
      end
    end

    context "when passed an array" do

      let(:first) do
        bunny.queue("minion.first")
      end

      let(:second) do
        bunny.queue("minion.second")
      end

      before do
        first.purge
        second.purge
      end

      context "when the array is empty" do

        it "raises an error" do
          expect { Minion.enqueue([], {}) }.to raise_error(RuntimeError)
        end
      end

      context "when the array has queue names" do

        let(:data) do
          { "field" => "value" }
        end

        before do
          Minion.enqueue([ "minion.first", "minion.second" ], data)
        end

        let(:message) do
          JSON.parse(first.pop[:payload])
        end

        it "adds the data to the queue" do
          message.should == data
        end

        it "adds the next job data" do
          message["next_job"].should == [ "minion.second" ]
        end
      end
    end
  end
end
