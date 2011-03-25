#!/usr/bin/env ruby

# there is shown dynamic creating and deleting subscriptions

$:.unshift File.dirname(__FILE__) + '/../lib'
require 'rubygems'
require 'minion'

include Minion

qu_name = "dinamic.one"

# job code-block
dinamic_proc = Proc.new {|args| /nothing here/ }

evented do
  
  # every 2 seconds check handler with name "dinamic.one"
  # and run if stoped
  EM.add_periodic_timer(2) do
    
    # find or crate
    unless handler = handlers.detect {|h| h.queue == qu_name }
      handler = job(qu_name, &dinamic_proc)
    end
    
    p handler
    
    handler.start_if_stoped
  end
  
  EM.add_timer(9) {
    # stop subscriotion of "dinamic.one"
    # it'll be started again on next tick of EM.add_periodic_timer above
    handlers.detect {|h| h.queue == qu_name }.stop
    enqueue(qu_name, :m => "dynamic again")
  }
end

enqueue(qu_name, :m => "dynamic get")

init_at_exit # force set exit callback