require 'uri'
require 'json' unless defined? ActiveSupport::JSON
require 'bunny'
require 'amqp'
require 'minion/handler'
require 'minion/daemon'

module Minion
  extend self

  @@handlers = []
  
  def url=(url)
    @@config_url = url
  end

  # push message with json-encoded data to queue named as job
  def enqueue(jobs, data = {})
    raise "cannot enqueue a nil job" if jobs.nil?
    raise "cannot enqueue an empty job" if jobs.empty?

    encoded = encode_json(data)
    
    [jobs].flatten.each do |job|
      connect.queue(job, :durable => true, :auto_delete => false).publish(encoded)
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
    handler = Minion::Handler.new(queue)
    
    handler.when = options[:when] if options[:when]
    handler.job = blk
    
    init_at_exit
    @@handlers << handler
    handler
  end

  # run once
  def init_at_exit
    @@init_at_exit ||= at_exit { Minion.run }
  end

  def encode_json(data)
    defined?(ActiveSupport::JSON) ? ActiveSupport::JSON.encode(data) : JSON.generate(data)
  end
  
  def decode_json(string)
    defined?(ActiveSupport::JSON) ? ActiveSupport::JSON.decode(string) : JSON.parse(string)
  end

  # check all job-hadlers
  def check_all
    @@handlers.each { |h| h.check }
  end

  # run amqp poll and initializes subscriptions
  def run
    log "Starting minion"

    Signal.trap('INT') { AMQP.stop{ EM.stop } }
    Signal.trap('TERM'){ AMQP.stop{ EM.stop } }

    EM.run do
      AMQP.start(amqp_config) do |connection|
        self.amqp = connection
        AMQP::Channel.new(connection).prefetch(1)
        check_all
      end
      
      @@evented && @@evented.call
    end
  end

  
  def amqp_url
    @@amqp_url ||= ENV["AMQP_URL"] || "amqp://guest:guest@localhost/"
  end

  def amqp_url=(url)
    @@amqp_url = url
  end

  # amqp connection
  attr_accessor :amqp
  
  def error_handler
    @@error_handler ||= nil
  end
  
  def handlers
    @@handlers
  end
  
  def evented(&blk)
    @@evented = blk
  end
  
  private

  # url-like config pasrser
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

  def new_connect
    Bunny.new(amqp_config).tap {|b| b.start }
  end

  # banny connection
  def connect
    @@connect ||= new_connect
  end

  # I decided not to use queue of tasks stored like one job.
  # It looks like queue in queue :) think it allows to make too diferent constructions
  def next_job(args, response)
    queue = args.delete("next_job")
    enqueue(queue,args.merge(response)) if queue and not queue.empty?
  end
  
end

