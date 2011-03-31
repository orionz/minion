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

logger do |msg|
  puts "--> #{msg}"
end

job "error.raising" do |args|
  p args
  sleep 1
  raise 'aaa'
end

enqueue('error.raising')