#!/usr/bin/env ruby

#
# This example illustrates the use of chaining
# callbacks to create building blocks with the
# message content being just a hash
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

job "add.bread" do |msg|
	msg.content.merge("bread" => "sourdough")
end

job "add.meat" do |msg|
	msg.content.merge("meat" => "turkey")
end

job "add.condiments" do |msg|
	msg.content.merge("condiments" => "mayo")
end

job "eat.sandwich" do |msg|
	puts "YUM!	A #{msg['meat']} on #{msg['bread']} sandwich with #{msg['condiments']}"
end

enqueue(["add.bread", "add.meat", "add.condiments", "eat.sandwich" ])

