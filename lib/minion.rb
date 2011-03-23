require "amqp"
require "bunny"
require "json" unless defined? ActiveSupport::JSON
require "uri"
require "minion/handler"
require "minion/version"

module Minion
  extend self

  # Handle when an error gets raised.
  #
  # @example Handle the error.
  #   Minion.error(exception)
  #
  # @param [ Exception ] exception The error that was raised.
  #
  # @return [ Object ] The output og the error handler block.
  def alert(exception)
    raise(exception) unless error_handling
    error_handling.call(exception)
  end

  # Add data to the supplied queue or queues. The hash will get converted to
  # JSON and placed on the queue as the JSON string.
  #
  # @example Place data on a single queue.
  #   Minion.enqueue("queue.name", { field: "value" })
  #
  # @example Place data on multiple queues.
  #   Minion.enqueue([ "queue.first", "queue.second" ], { field: "value" })
  #
  # @param [ String, Array<String> ] name The name or names of the queues.
  # @param [ Hash ] data The payload to send.
  #
  # @raise [ RuntimeError ] If the name is nil or empty.
  def enqueue(name, data = nil)
    raise "cannot enqueue an empty or nil name" if name.nil? || name.empty?
    encoded = JSON.dump(data || {})

    [ name ].flatten.each do |queue|
      info("send: #{queue}:#{encoded}")
      bunny.queue(queue, durable: true, auto_delete: false).publish(encoded)
    end
  end

  # Define an optional method of changing the ways errors get handled.
  #
  # @example Define a custom error handler.
  #   Minion.error do |e|
  #     puts "I got an error - #{e.message}"
  #   end
  #
  # @param [ Proc ] block The block that will handle the error.
  def error(&block)
    @error_handling = block
  end

  # Log the supplied information message.
  #
  # @example Log the message.
  #   Minion.info("something happened")
  #
  # @return [ Object ] The output of the logging block.
  def info(message)
    logging.call(message)
  end

  # Sets up a subscriber to a queue to process jobs.
  #
  # @example Set up the subscriber.
  #   Minion.job "my.queue.name" do |attributes|
  #     puts "Here's the message data: #{attributes"
  #   end
  #
  # @param [ String ] queue The queue to subscribe to.
  # @param [ Hash ] options Options for the subscriber.
  #
  # @option options [ lambda ] :when Conditionally process the job.
  def job(queue, options = {}, &block)
    handler = Minion::Handler.new(queue)
    handler.when = options[:when] if options[:when]
    handler.unsub = -> {
      info("unsubscribing to #{queue}")
      AMQP::Channel.queue(queue, durable: true, auto_delete: false).unsubscribe
    }
    handler.sub = -> {
      info("subscribing to #{queue}")
      AMQP::Channel.queue(
        queue,
        durable: true,
        auto_delete: false
      ).subscribe(ack: true) do |header, message|
        return if AMQP.closing?
        begin
          info("recv: #{queue}:#{message}")
          result = block.call(decode(message))
        rescue Object => e
          alert(e)
        end
        header.ack
        check_handlers
      end
    }
    @handlers ||= []
    at_exit { Minion.run } if @handlers.size == 0
    @handlers << handler
  end

  # Define an optional method of changing the ways logging is handled.
  #
  # @example Define a custom logger.
  #   Minion.logger do |message|
  #     puts "Something did something - #{message}"
  #   end
  #
  # @param [ Proc ] block The block that will handle the logging.
  def logger(&block)
    @logging = block
  end

  # Runs the minion subscribers.
  #
  # @example Run the subscribers.
  #   Minion.run
  def run
    info("Starting minion")
    Signal.trap("INT") { AMQP.stop { EM.stop } }
    Signal.trap("TERM") { AMQP.stop { EM.stop } }

    EM.run do
      AMQP.start(amqp_config) do
        MQ.prefetch(1)
        check_handlers
      end
    end
  end

  # Get the url for the amqp server.
  #
  # @example Get the url.
  #   Minion.url
  #
  # @return [ String ] The url.
  def url
    @url ||= (ENV["AMQP_URL"] || "amqp://guest:guest@localhost/")
  end

  # Set the url to the amqp server.
  #
  # @example Set the url.
  #   Minion.url = "amqp://user:password@host:port/vhost"
  #
  # @return [ String ] The new url.
  def url=(url)
    @url = url
  end

  private

  # Get the bunny instance which is used for the synchronous communication.
  #
  # @example Get the bunny.
  #   Minion.bunny
  #
  # @return [ Bunny ] The new bunny, all configured.
  def bunny
    @bunny ||= Bunny.new(config).tap { |b| b.start }
  end

  # Gets the hash of configuration options.
  #
  # @example Get the configuration hash.
  #   Minion.config
  #
  # @return [ Hash ] The configuration options.
  def config
    uri = URI.parse(url)
    {
      vhost: uri.path,
      host: uri.host,
      user: uri.user,
      port: (uri.port || 5672),
      pass: uri.password
    }
  rescue Object => e
    raise("invalid AMQP_URL: #{uri.inspect} (#{e})")
  end

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

  # Checks each of the handlers.
  #
  # @example Check all handlers.
  #   Minion.check_handlers
  def check_handlers
    @handlers.each { |handler| handler.check }
  end

  # Get the error handler for this class.
  #
  # @example Get the error handler.
  #   Minion.error_handling
  #
  # @return [ lambda, nil ] The handler or nil.
  def error_handling
    @error_handling
  end

  # Get the logger for this class. If nothing had been specified will default
  # to a basic time/message print.
  #
  # @example Get the logger.
  #   Minion.logging
  #
  # @return [ lambda ] The logger.
  def logging
    @logging ||= ->(msg) { puts("#{Time.now} :minion: #{msg}") }
  end
end

