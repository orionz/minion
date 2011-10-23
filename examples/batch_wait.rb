#!/usr/bin/env ruby

#
# This example illustrates the use batching
# when we want to wait until the hit an exact
# number of messages before running
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


job "do.only_in_tens", :batch_size => 10, :wait => true do |msg|
	puts "got #{msg.batch.size} messages"
end

# We won't run this, but just so you know, this is the
# same result as the "batch.rb" example 
job "do.in_tens_or_emtpy", :batch_size => 10, :wait => false do |msg|
	puts "got #{msg.batch.size} messages"
end

27.times{ Minion.enqueue 'do.only_in_tens', {"something" => true} }
