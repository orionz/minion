require 'uri'
require 'json'
require 'mq'
require 'bunny'

module Minion
	extend self

	def enqueue(queue, data)
		log "send: #{queue}:#{data.to_json}"
		bunny.queue(queue, :durable => true, :auto_delete => false).publish(data.to_json)
	end

	def on_error(&blk)
		@@error_handler = blk
	end

	def logger(&blk)
		@@logger = blk
	end

	def job(queue, &blk)
		handler do
			MQ.queue(queue).subscribe(:ack => true) do |h,m|
				return if AMQP.closing?
				begin
					log "recv: #{queue}:#{m}"

					args = JSON.load(m)

					result = yield(args)

					next_job(args, result)
				rescue Object => e
					raise unless error_handler
					error_handler.call(e)
				end
				h.ack
			end
		end
	end

	def run
		log "Starting minion"

		Signal.trap('INT') { AMQP.stop{ EM.stop } }
		Signal.trap('TERM'){ AMQP.stop{ EM.stop } }

		EM.run do
			AMQP.start(amqp_config) do
				MQ.prefetch(1)
				@@handlers.each { |h| h.call }
			end
		end
	end

	private

	def amqp_config
		uri = URI.parse(ENV["AMQP_URI"])
		raise unless (uri.scheme == "rabbit" or uri.scheme == "amqp")
		{
			:vhost => uri.path,
			:host => uri.host,
			:user => uri.user,
			:port => (uri.port || 5672),
			:pass => uri.password
		}
	rescue
		raise "invalid AMQP_URI: #{uri.inspect}"
	end

	def new_bunny
		b = Bunny.new(amqp_config)
		b.start
		b
	end

	def bunny
		@@bunny ||= new_bunny
	end

	def log(msg)
		@@logger ||= proc { |m| puts "#{Time.now} :minion: #{m}" }
		@@logger.call(msg)
	end

	def handler(&blk)
		@@handlers ||= []
		at_exit { Minion.run } if @@handlers.size == 0
		@@handlers << blk
	end

	def next_job(args, response)
		queue = if args["next_job"].respond_to? :shift
			args["next_job"].shift
		else
			args.delete("next_job")
		end

		enqueue(queue,args.merge(response)) if queue
	end

	def error_handler
		@@error_handler ||= nil
	end
end

