#!/usr/bin/env ruby

#
# This example illustrates the use batching
# when we want to wait some # of seconds for an
# exact number of messages before running,
# but if we don't get that many, we'll go ahead
# anyways.
#
# This prevents some odd batch counts, but allows
# for flexibility of the queue size
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

Thread.new do
  puts "------------------------------------------"
  puts "First, no waiting with artificial delays"
  puts "------------------------------------------"
  3.times{ Minion.enqueue 'do.no_waiting', {"something" => true} }
  sleep 0.2
  4.times{ Minion.enqueue 'do.no_waiting', {"something" => true} }
  sleep 5
  puts "------------------------------------------"
  puts "Now if we give it a second, all is well"
  puts "------------------------------------------"
  3.times{ Minion.enqueue 'do.in_tens_or_wait_2', {"something" => true} }
  sleep 0.2
  4.times{ Minion.enqueue 'do.in_tens_or_wait_2', {"something" => true} }
end

job "do.no_waiting", :batch_size => 10 do |msg|
  puts "got #{msg.batch.size} messages"
end

job "do.in_tens_or_wait_2", :batch_size => 10, :wait => 2 do |msg|
  puts "got #{msg.batch.size} messages"
end