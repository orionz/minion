#!/usr/bin/env ruby

$:.unshift File.dirname(__FILE__) + '/../lib'
require 'rubygems'
require 'minion'

include Minion

error do |exception,queue,message,headers|
  puts "got an error processing queue #{queue}"
  puts exception.message
  puts exception.backtrace
end

job "add.bread" do |args|
	{ "bread" => "sourdough" }
end

job "add.meat" do |args|
	{ "meat" => "turkey" }
end

job "add.condiments" do |args|
	{ "condiments" => "mayo" }
end

job "eat.sandwich" do |args|
	puts "YUM!  A #{args['meat']} on #{args['bread']} sandwich with #{args['condiments']}"
end

enqueue(["add.bread", "add.meat", "add.condiments", "eat.sandwich" ])

