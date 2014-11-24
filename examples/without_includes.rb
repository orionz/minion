#!/usr/bin/env ruby

$:.unshift File.dirname(__FILE__) + '/../lib'
require 'rubygems'
require 'minion'
require "active_support"


Minion.error do |exception,queue,message,headers|
  puts "got an error processing queue #{queue}"
  puts exception.message
  puts exception.backtrace
end

Minion.logger do |msg|
  puts "--> #{msg}"
end

Minion.job "math.incr" do |args|
  { "number" => (1 + args["number"].to_i) }
end

Minion.job "math.double" do |args|
  { "number" => (2 * args["number"].to_i) }
end

Minion.job "math.square" do |args|
  { "number" => (args["number"].to_i * args["number"].to_i) }
end

Minion.job "math.print" do |args|
  puts "NUMBER -----> #{args["number"]}"
end

Minion.enqueue([ "math.incr", "math.double", "math.square", "math.incr", "math.double", "math.print" ], { :number => 3 })

