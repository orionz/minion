# encoding: utf-8
require "amqp"
require "bunny"
require "json" unless defined? ActiveSupport::JSON
require "uri"
require "minion/handler"
require "minion/version"
require "minion/message"
require "ext/string"

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

  # Gets the hash of configuration options.
  #
  # @example Get the configuration hash.
  #   Minion.config
  #
  # @return [ Hash ] The configuration options.
  def config
    uri = URI.parse(url)
    {
      :vhost => uri.path,
      :host => uri.host,
      :user => uri.user,
      :port => (uri.port || 5672),
      :pass => uri.password
    }
  rescue Object => e
    raise("invalid AMQP_URL: #{uri.inspect} (#{e})")
  end

  # Add content to the supplied queue or queues. The hash will get converted to
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
  def enqueue(queues, data = {})
    raise "Cannot enqueue an empty or nil name" if queues.nil? || queues.empty?
    # Wrap raw data when we receive it
    data = {'content' => data} unless data.class == Hash && data['content']
    if queues.respond_to? :shift
      queue = queues.shift
      data['callbacks'] = queues
    else
      queue = queues
    end
    
    # @todo: Durran: Any multi-byte character in the JSON causes a bad_payload
    #   error on the rabbitmq side. It seems a fix in the old amqp gem
    #   regressed in the new fork.
    encoded = JSON.dump(data).force_encoding("ISO-8859-1")
    
    Minion.info("Send: #{queue}:#{encoded}")
    connect do |bunny|
      q = bunny.queue(queue, :durable => true, :auto_delete => false)
      e = bunny.exchange('') # Connect to default exchange
      e.publish(encoded, :key => q.name) 
    end
  end
    
  # Get the message count for a specific queue
  #
  # @example Get the message count for queue 'minion.test'.
  #   Minion.message_count('minion.test')
  #
  # @return [ Fixnum ] the number of messages
  def message_count(queue)
    connect do |bunny|
      return bunny.queue(queue, :durable => true, :auto_delete => false).message_count
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
    @@error_handling = block
  end

  # Runs each of the handlers.
  #
  # @example Check all handlers.
  #   Minion.check_handlers
  def execute_handlers
    @@handlers.each { |handler| handler.execute }
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
  # @option options [ boolean ] :ack Should we automatically ack the message?
  def job(queue, options = {}, &block)
    Minion::Handler.new(queue, block, options).tap do |handler|
      @@handlers ||= []
      at_exit { Minion.run } if @@handlers.size == 0
      @@handlers << handler
    end
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
    @@logging = block
  end

  # Runs the minion subscribers.
  #
  # @example Run the subscribers.
  #   Minion.run
  def run
    Minion.info("Starting minion")
    Signal.trap("INT") { AMQP.stop { EM.stop } }
    Signal.trap("TERM") { AMQP.stop { EM.stop } }

    EM.run do
      AMQP.start(config) do
        AMQP::Channel.new.prefetch(1)
        execute_handlers
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
    @@url ||= (ENV["AMQP_URL"] || "amqp://guest:guest@localhost/")
  end

  # Set the url to the amqp server.
  #
  # @example Set the url.
  #   Minion.url = "amqp://user:password@host:port/vhost"
  #
  # @return [ String ] The new url.
  def url=(url)
    @@url = url
  end
  
  private

  # Get the bunny instance which is used for the synchronous communication.
  #
  # @example Get the bunny.
  #   Minion.bunny
  #
  # @return [ Bunny ] The new bunny, all configured.
  def connect
    Bunny.new(config).tap do |bunny|
      bunny.start
      yield(bunny) if block_given?
      bunny.stop
    end
  end

  # Get the error handler for this class.
  #
  # @example Get the error handler.
  #   Minion.error_handling
  #
  # @return [ lambda, nil ] The handler or nil.
  def error_handling
    @@error_handling ||= nil
  end

  # Get the logger for this class. If nothing had been specified will default
  # to a basic time/message print.
  #
  # @example Get the logger.
  #   Minion.logging
  #
  # @return [ lambda ] The logger.
  def logging
    @@logging ||= lambda { |msg| puts("#{Time.now} :minion: #{msg}") }
  end
end

