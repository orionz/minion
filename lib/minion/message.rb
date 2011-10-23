require File.join 'active_support', 'core_ext', 'module', 'delegation'

module Minion
  class Message
    attr_accessor :content, :callbacks, :headers, :batch
    delegate :clear, :map, :each, :size, :count, :[], :each_with_index, :cycle, :shuffle, :to => :content
    
    def initialize json="{}", header=nil
      data = decode(json)
      @headers   = [header]
      @callbacks = data['callbacks']
      @content   = data['content']
      @batch     = data['batch'] || []
    end
    
    def << data
      @content << data
    end
    
    # Enqueue a job for the next callback in the chain
    #
    # @return void
    def callback
      headers.clear
      if callbacks and not callbacks.empty?
        queue_name = callbacks.shift
        Minion.enqueue(queue_name, as_json)
      end
    end

    private
    
    # Decode the json string into a hash.
    #
    # @example Decode the json.
    #   decode("{ field : "value" }")
    #
    # @param [ String ] json The json string.
    #
    # @return [ Hash ] The json as a hash.
    def decode(json)
      defined?(ActiveSupport::JSON) ?
        ActiveSupport::JSON.decode(json) : JSON.load(json)
    end
    
    def as_json
      { 'callbacks' => callbacks,
        'headers' => headers,
        'content' => content
      }
    end
    
    def to_json
      JSON.dump(as_json || {}).force_encoding("ISO-8859-1")
    end
    
  end
end