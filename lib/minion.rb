require 'uri'
require 'json' unless defined? ActiveSupport::JSON
require 'amqp'
require 'bunny'
require 'minion/handler'
require 'minion/version'

module Minion
  extend self

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
    data ||= {}

    encoded = JSON.dump(data)

    [ name ].flatten.each do |queue|
      log("send: #{queue}:#{encoded}")
      bunny.queue(queue, :durable => true, :auto_delete => false).publish(encoded)
    end
  end

  def log(msg)
    @@logger ||= proc { |m| puts "#{Time.now} :minion: #{m}" }
    @@logger.call(msg)
  end

  def error(&blk)
    @@error_handler = blk
  end

  def logger(&blk)
    @@logger = blk
  end

  def job(queue, options = {}, &blk)
    handler = Minion::Handler.new queue
    handler.when = options[:when] if options[:when]
    handler.unsub = lambda do
      log "unsubscribing to #{queue}"
      MQ.queue(queue, :durable => true, :auto_delete => false).unsubscribe
    end
    handler.sub = lambda do
      log "subscribing to #{queue}"
      MQ.queue(queue, :durable => true, :auto_delete => false).subscribe(:ack => true) do |h,m|
        return if AMQP.closing?
        begin
          log "recv: #{queue}:#{m}"
          args = decode_json(m)
          result = yield(args)
        rescue Object => e
          raise unless error_handler
          error_handler.call(e,queue,m,h)
        end
        h.ack
        check_all
      end
    end
    @@handlers ||= []
    at_exit { Minion.run } if @@handlers.size == 0
    @@handlers << handler
  end

  def decode_json(string)
    if defined? ActiveSupport::JSON
      ActiveSupport::JSON.decode string
    else
      JSON.load string
    end
  end

  def check_all
    @@handlers.each { |h| h.check }
  end

  def run
    log "Starting minion"

    Signal.trap('INT') { AMQP.stop{ EM.stop } }
    Signal.trap('TERM'){ AMQP.stop{ EM.stop } }

    EM.run do
      AMQP.start(amqp_config) do
        MQ.prefetch(1)
        check_all
      end
    end
  end

  def amqp_url
    @@amqp_url ||= ENV["AMQP_URL"] || "amqp://guest:guest@localhost/"
  end

  def amqp_url=(url)
    @@amqp_url = url
  end

  def url=(url)
    @@config_url = url
  end

  private

  def amqp_config
    uri = URI.parse(amqp_url)
    {
      :vhost => uri.path,
      :host => uri.host,
      :user => uri.user,
      :port => (uri.port || 5672),
      :pass => uri.password
    }
  rescue Object => e
    raise "invalid AMQP_URL: #{uri.inspect} (#{e})"
  end

  def bunny
    @@bunny ||= Bunny.new(amqp_config).tap { |b| b.start }
  end

  def error_handler
    @@error_handler ||= nil
  end
end

