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
      AMQP::Channel.stubs(:new).returns(channel)
    end

    context "when the queue is subscribable" do

      let(:handler) do
        described_class.new("minion.test", ->{ true })
      end

      context "when the handler is not already running" do

        before do
          channel.expects(:queue).with(
            "minion.test", durable: true, auto_delete: false
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
        described_class.new("minion.test", ->{ true }, ->{ false })
      end

      before do
        channel.expects(:queue).with(
          "minion.test", durable: true, auto_delete: false
        ).returns(queue)
      end

      it "unsubscribes from the queue" do
        queue.expects(:unsubscribe)
        handler.execute
      end
    end
  end
end
