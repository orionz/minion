#!/usr/bin/env ruby

$:.unshift File.dirname(__FILE__) + '/../lib'
require 'rubygems'
require 'minion'

Minion::Daemon.log = "./log/daemon.log"
Minion::Daemon.pid = "./log/daemon.pid"

Minion::Daemon.fork_or_skip

puts "Daemon started #{Process.pid}"

Minion.run

sleep 10_000