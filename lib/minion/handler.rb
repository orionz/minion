module Minion
  # simple class, what stores lambdas with job and channel subscription
  
	class Handler
		attr_accessor :queue, :when, :on, :channel, :job
		
		def initialize(queue)
			@queue = queue
			@when = lambda { true }
			@job = lambda {}
			@on = false
		end
		
		def unsub
			Minion.log "unsubscribing to #{queue}"
			channel.queue(queue, :durable => true, :auto_delete => false).unsubscribe
		end

    def sub
			Minion.log "subscribing to #{queue}"
			channel = AMQP::Channel.new(Minion.amqp)
			
			channel.queue(queue, :durable => true, :auto_delete => false).subscribe(:ack => true) do |h, message|
				return if AMQP.closing?
				begin
				  
					Minion.log "recv: #{queue}:#{message}"
					args = Minion.decode_json(message)
          job.call(args)
          
				rescue Object => e
					raise unless Minion.error_handler
					Minion.error_handler.call(e, queue, message, h)
				end
				h.ack
				Minion.check_all
			end
    end

		def should_sub?
			@when.call
		end

		def check
			if should_sub?
				sub unless @on
				@on = true
			else
				unsub if @on
				@on = false
			end
		end

		def to_s
			"<handler queue=#{@queue} on=#{@on}>"
		end
	end
end
