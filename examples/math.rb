#!/usr/bin/env ruby

#
# This example illustrates the use of chaining
# callbacks to create building blocks with the
# message content being just an integer
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

job "math.incr" do |msg|
	msg.content.to_i + 1
end

job "math.double" do |msg|
	msg.content.to_i * 2
end

job "math.square" do |msg|
	msg.content.to_i * msg.content.to_i
end

job "math.print" do |msg|
	puts "NUMBER -----> #{msg.content}"
end

enqueue([ "math.incr", "math.double", "math.square", "math.incr", "math.double", "math.print" ], 3)

