#!/usr/bin/env ruby

require 'rubygems'
require 'minion'

include Minion

error do |e|
	puts "got an error!"
end

logger do |msg|
	puts "--> #{msg}"
end

$listen = true

job "do.once", :when => lambda { $listen }  do |args|
	puts "Do this one action - then unsubscribe..."
	$listen = false
end

enqueue("do.once",[])
enqueue("do.once",[])

