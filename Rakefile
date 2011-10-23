require "bundler"
Bundler.setup

require "rake"
require "rake/rdoctask"
require "rspec"
require "rspec/core/rake_task"

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "minion/version"

task :build do
  system "gem build minion.gemspec"
end

task :install => :build do
  system "sudo gem install minion-#{Minion::VERSION}.gem"
end

task :release => :build do
  system "git tag -a #{Minion::VERSION} -m 'Tagging #{Minion::VERSION}'"
  system "git push --tags"
  system "gem push mongoid-#{Minion::VERSION}.gem"
end

Rspec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = "spec/**/*_spec.rb"
end

task :default => :spec
