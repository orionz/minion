#!/usr/bin/env ruby

#
# This example illustrates the use batching
# and chaining of callbacks in a single example.
# Another example of doing a map-reduce operation.
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

MAKINGS = {
  'bread'      => %w[wheat rye sourdough white pumpernickle],
  'meat'       => %w[turkey ham pastrami salami],
  'condiments' => %w[mayo mustard relish sourkraut]
}

job "add.bread", :batch_size => 5 do |msg|
  puts "Puts making #{msg.batch.size} sandwiches"
	msg.batch.map{|s| s.merge("bread" => MAKINGS['bread'].sample)}
end

job "add.meat" do |msg|
	msg.map{|s| s.merge("meat" => MAKINGS['meat'].sample)}
end

job "add.condiments" do |msg|
  msg.map{|s| s.merge("condiments" => MAKINGS['condiments'].sample)}
end

job "eat.sandwich" do |msg|
  msg.each_with_index{|s, i| puts "SANDWICH ##{i}:  A #{s['meat']} on #{s['bread']} sandwich with #{s['condiments']}"}
end

15.times{ enqueue(["add.bread", "add.meat", "add.condiments", "eat.sandwich" ]) }
