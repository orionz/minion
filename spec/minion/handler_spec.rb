require "spec_helper"

describe Minion::Handler do

  before(:all) do
    Minion.logger {}
  end

  let(:channel) do
    stub.quacks_like(AMQP::Channel.allocate)
  end

  let(:queue) do
    stub.quacks_like(AMQP::Queue.allocate)
  end

  describe "#execute" do

    before do
      channel.expects(:prefetch).at_most_once
      AMQP::Channel.stubs(:new).returns(channel)
    end

    context "when the queue is subscribable" do

      let(:handler) do
        described_class.new("minion.test", lambda{ true })
      end

      context "when the handler is not already running" do

        before do
          channel.expects(:queue).with(
            "minion.test", :durable => true, :auto_delete => false
          ).returns(queue)
        end

        it "subscribes to the queue" do
          queue.expects(:subscribe)
          handler.execute
        end
      end

      context "when the handler is running" do

        before do
          handler.instance_variable_set(:@running, true)
        end

        it "does not subscribe again" do
          channel.expects(:queue).never
          handler.execute
        end
      end
    end

    context "when the queue is not subscribable" do

      let(:handler) do
        described_class.new("minion.test", lambda{ true }, :when => lambda{ false })
      end

      before do
        channel.expects(:queue).with(
          "minion.test", :durable => true, :auto_delete => false
        ).returns(queue)
      end

      it "unsubscribes from the queue" do
        queue.expects(:unsubscribe)
        handler.execute
      end
    end
    
    context "when wait parameter is specified" do
      it "should raise an error" do
        expect do
          described_class.new("minion.test", lambda{ |batch| {"content" => true} }, :wait => true)
        end.to raise_error(ArgumentError)
      end
    end
    
    context "when a batch size is specified" do
      let(:block) do
        lambda{ |batch| {"content" => true} }
      end
      
      let(:handler) do
        described_class.new("minion.test", block, :batch_size => 10)
      end
      
      let(:header) do
        stub.quacks_like(AMQP::Header.allocate)
      end
      
      let(:serialized) do
        '{"content":{"field":"value"}}'
      end
      
      let(:batch) do
        [header, serialized] * 10
      end
            
      before do
        queue.expects(:subscribe).multiple_yields(batch)
        channel.expects(:queue).with(
          "minion.test", :durable => true, :auto_delete => false
        ).returns(queue)
        Minion.expects(:execute_handlers)
        header.expects(:ack)
      end
      
      it "calls once for 10 messages" do
        block.expects(:call).once
        handler.execute
      end
      
      context "when wait parameter is specified" do
        let(:handler) do
          described_class.new("minion.test", block, :batch_size => 10, :wait => true)
        end
        
        it "doesn't call for 9 messages" do
          block.expects(:call).never
          handler.execute
        end
      end
      
      context "when wait paramter is numeric" do
        let(:batch) do
          [header, serialized] * 9
        end
        
        let(:handler) do
          described_class.new("minion.test", block, :batch_size => 10, :wait => 2)
        end
        
        it "calls once for 9 messages after waiting a bit" do          
          block.expects(:call).once
          handler.execute
        end
      end
    end
    
    
  end
end
