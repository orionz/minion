#!/usr/bin/env ruby

#
# This example illustrates the use of batching
# messages together.  This way work can be
# distributed in small chunks, but worked on
# in larger groups
#

$:.unshift File.dirname(__FILE__) + '/../lib'
require 'rubygems'
require 'minion'

include Minion

error do |exception,queue,message,headers|
	puts "got an error processing queue #{queue}"
	puts exception.message
	puts exception.backtrace
end

logger do |msg|
	puts "--> #{msg}"
end


job "do.many", :batch_size => 10 do |msg|
	puts "got #{msg.batch.size} messages"
end

27.times{ Minion.enqueue 'do.many', {"something" => true} }