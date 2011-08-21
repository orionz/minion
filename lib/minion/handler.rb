# encoding: utf-8
module Minion
  class Handler
    attr_reader :queue, :block

    # Executes the handler. Will subscribe to a queue or unsubscribe to it
    # depending on the conditions.
    #
    # @example Execute the handler.
    #   handler.execute
    def execute
      subscribable? ? subscribe : unsubscribe
    end

    # Instantiate the new handler. Takes a queue name and optional lambda to
    # determine conditionally if a queue is subscribable.
    #
    # @example Create the new handler.
    #   Handler.new("minion.test")
    #
    # @param [ String ] queue The name of the queue.
    # @param [ Hash ] 
    # @option options [ lambda ] :when The block for conditionally subscribing.
    # @option options [ boolean ] :ack Should we automatically ack the message?
    def initialize(queue, block, options = {})
      @queue, @block = queue, block
      @subscribable = options[:when]
      @ack = ! (options[:ack] == false) # Ack is either true or nil
    end

    private

    # Decode the json string into a hash.
    #
    # @example Decode the json.
    #   Minion.decode_json("{ field : "value" }")
    #
    # @param [ String ] json The json string.
    #
    # @return [ Hash ] The json as a hash.
    def decode(json)
      defined?(ActiveSupport::JSON) ?
        ActiveSupport::JSON.decode(json) : JSON.load(json)
    end

    # Returns true if the handler is already subscribed to the queue.
    #
    # @example Is the handler running?
    #   handler.running?
    #
    # @return [ true, false ] Is the handler running?
    def running?
      !!@running
    end

    # Determines if the queue is able to be subscribed to.
    #
    # @example Is the queue subscribable?
    #   handler.subscribable?
    def subscribable?
      @subscribable ? @subscribable.call : true
    end

    # Subscribe to the queue. Will do so if the handler is not already
    # subscribed.
    #
    # @example Subscribe to the queue.
    #   handler.subscribe
    def subscribe
      unless running?
        Minion.info("Subscribing to #{queue}")
        AMQP::Channel.new.queue(queue, durable: true, auto_delete: false).subscribe(ack: true) do |h, m|
          return if AMQP.closing?
          begin
            Minion.info("Received: #{queue}:#{m}, #{h}")
            block.call(decode(m), h)
          rescue Object => e
            Minion.alert(e)
          end
          h.ack if @ack
          Minion.execute_handlers
        end
        @running = true
      end
    end

    # Get a string respresentation of the handler.
    #
    # @example Print out the string.
    #   handler.to_s
    #
    # @return [ String ] The handler as a string.
    def to_s
      "<handler queue=#{@queue} on=#{@on}>"
    end

    # Unsubscribe from the queue.
    #
    # @example Unsubscribe from the queue.
    #   handler.unsubscribe
    def unsubscribe
      Minion.info("Unsubscribing to #{queue}")
      AMQP::Channel.new.queue(queue, durable: true, auto_delete: false).unsubscribe
      @running = false
    end
  end
end
