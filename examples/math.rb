#!/usr/bin/env ruby

require 'rubygems'
require 'minion'

include Minion

on_error do |e|
	puts "got an error!"
end

logger do |msg|
	puts "--> #{msg}"
end

job "math.incr" do |args|
	{ "number" => (1 + args["number"].to_i) }
end

job "math.double" do |args|
	{ "number" => (2 * args["number"].to_i) }
end

job "math.square" do |args|
	{ "number" => (args["number"].to_i * args["number"].to_i) }
end

job "math.print" do |args|
	puts "NUMBER -----> #{args["number"]}"
end

enqueue([ "math.incr", "math.double", "math.square", "math.incr", "math.double", "math.print" ], { :number => 3 })

