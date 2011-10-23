# encoding: utf-8
require "spec_helper"

describe Minion do

  let(:bunny) do
    Bunny.new(Minion.config).tap do |bunny|
      bunny.start
    end
  end

  before(:all) do
    Minion.logger {}
  end

  describe ".alert" do

    context "when an error handler is provided" do

      let(:error) do
        RuntimeError.new("testing")
      end

      before do
        Minion.error do |error|
          error.message
        end
      end

      after do
        Minion.error
      end

      it "delegates to the handler" do
        Minion.alert(error).should == "testing"
      end
    end

    context "when an error handler is not provided" do

      let(:error) do
        RuntimeError.new("testing")
      end

      it "raises the error" do
        expect { Minion.alert(error) }.to raise_error(RuntimeError)
      end
    end
  end

  describe ".enqueue" do

    let(:queue) do
      bunny.queue("minion.test", :durable => true, :auto_delete => false)
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
          message.should == {"content" => {}}
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
          message.should == {"content" => nil}
        end
      end

      context "when data is provided" do

        context "when the data has no special characters" do

          let(:data) do
            {"content"=>{"field"=>"value"}}
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

        context "when the data contains special characters" do

          let(:data) do
            {"content"=>{"field"=>"öüäßÖÜÄ"}}
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
    end

    context "when provided a nil queue" do

      it "raises an error" do
        expect { Minion.enqueue(nil, {}) }.to raise_error(RuntimeError)
      end
    end

    context "when passed an array" do

      let(:first) do
        bunny.queue("minion.first", :durable => true, :auto_delete => false)
      end

      before do
        first.purge
      end

      context "when the array is empty" do

        it "raises an error" do
          expect { Minion.enqueue([], {}) }.to raise_error(RuntimeError)
        end
      end

      context "when the array has queue names" do

        let(:data) do
          {"field"=>"value"}
        end
        
        let(:serialized) do
          {"content"=>{"field"=>"value"}, "callbacks"=>["minion.second", "minion.third"]}
        end

        before do
          Minion.enqueue([ "minion.first", "minion.second", "minion.third" ], data)
        end

        let(:message) do
          JSON.parse(first.pop[:payload])
        end

        it "adds the serialized data to the first queue" do
          message.should == serialized
        end
        
        context "when the data has already been serialized" do
          before do
            Minion.enqueue([ "minion.first", "minion.second", "minion.third" ], serialized)
          end
          
          let(:message) do
            JSON.parse(first.pop[:payload])
          end
          
          it "adds has the same serialized data in the first queue" do
            message.should == serialized
          end
        end
      end
    end
  end


  describe ".error_handling" do

    context "when nothing has been defined" do

      it "returns nil" do
        Minion.send(:error_handling).should be_nil
      end
    end
  end

  describe ".error" do

    let(:block) do
      lambda{ "testing" }
    end

    before do
      Minion.error(&block)
    end

    it "sets the error handling to the provided block" do
      Minion.send(:error_handling).should == block
    end
  end

  describe ".info" do

    let(:block) do
      lambda{ |message| message }
    end

    before do
      Minion.logger(&block)
    end

    it "delegates the logging to the provided block" do
      Minion.info("testing").should == "testing"
    end
  end
end
