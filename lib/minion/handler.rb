require 'pp'
# encoding: utf-8
module Minion
  class Handler
    attr_reader :queue_name, :block, :batch_size, :wait

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
    # @param [ String ] queue_name The name of the queue.
    # @param [ Hash ] 
    # @option options [ lambda ] :when The block for conditionally subscribing.
    # @option options [ fixnum ] :batch_size The number of elements per batch
    # @option options [ symbol ] :map The type of map operation: fanout or reduce
    def initialize(queue_name, block, options = {})
      @queue_name, @block = queue_name, block
      @subscribable = options[:when]
      @batch_size = options[:batch_size]
      @wait = options[:wait] || false
      raise ArgumentError, "wait parameter makes no sense without a batch_size" if (@wait && ! @batch_size)
    end

    private

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
        Minion.info("Subscribing to #{queue_name}")
        chan = AMQP::Channel.new
        chan.prefetch(1)
        queue = chan.queue(queue_name, :durable => true, :auto_delete => false)
        if batch_size && batch_size > 1
          process_batch(queue)
        else
          process_single_message(queue)
        end
        @running = true
      end
      
    end
    
    # Process a multiple messages from a queue as a batch
    #
    # @example Subscribe to the queue.
    #   handler.process_batch(queue)
    # 
    # @param [ AMQP::Queue ]
    #
    def process_batch(queue)
      # Our batch message will have an array for it's content
      msg = Message.new
      queue.subscribe(:ack => true) do |h, m|
        return if AMQP.closing?
        Minion.info("Received: #{queue_name}:#{m}, #{h}")
        args = decode(m)
        
        # All messages in the batch get the callbacks from
        # the first message.  This is why when using chained
        # callbacks on batches, you always have to use the
        # same combo of callback-queues!
        msg.callbacks = args['callbacks']
        msg.batch << args['content']
        h.ack # acks are useless in batch-mode.
              # You'll have to make sure you requeue manually 
        if (msg.batch.size == batch_size) || process_anyway?
          msg.content = block.call(msg)
          msg.callback
          msg.batch.clear
        end
        Minion.execute_handlers
      end
    rescue Object => e
      Minion.alert(e)
    end
    
    # Process a single message from a queue
    #
    # @example Subscribe to the queue.
    #   handler.process_single_message(queue)
    # 
    # @param [ AMQP::Queue ]
    #
    def process_single_message(queue)
      queue.subscribe(:ack => true) do |h, m|
        return if AMQP.closing?
        Minion.info("Received: #{queue_name}:#{m}, #{h}")
        msg = Message.new(m, h)
        msg.content = block.call(msg)
        h.ack
        msg.callback
        Minion.execute_handlers
      end
    rescue Object => e
      Minion.alert(e)
    end

    # Get a string respresentation of the handler.
    #
    # @example Print out the string.
    #   handler.to_s
    #
    # @return [ String ] The handler as a string.
    def to_s
      "<handler queue_name=#{@queue_name} on=#{@on}>"
    end

    # Unsubscribe from the queue.
    #
    # @example Unsubscribe from the queue.
    #   handler.unsubscribe
    def unsubscribe
      Minion.info("Unsubscribing to #{queue_name}")
      AMQP::Channel.new.queue(queue_name, :durable => true, :auto_delete => false).unsubscribe
      @running = false
    end
    
    private

    def decode(json)
      defined?(ActiveSupport::JSON) ?
        ActiveSupport::JSON.decode(json) : JSON.load(json)
    end
    
    # Determine if we should process a batch even if
    # we haven't reached the batch_size
    #
    # @return [ Boolean ] if we should go ahead and process the batch
    def process_anyway?
      return false if Minion.message_count(queue_name) != 0 # there's work to be done!
      case wait
      when true  then false # Wait indefinitely
      when false then true  # Don't wait at all
      when Numeric
        (0..wait).each do |i|
          return false if Minion.message_count(queue_name) != 0
          sleep 1
        end
        # Wait this many, then if the queue is still empty, go ahead
        Minion.message_count(queue_name) == 0
      end
    end
  end
end
