require 'jeweler'

Jeweler::Tasks.new do |s|
  s.name = "minion"
  s.description = "Super simple job queue over AMQP"
  s.summary = s.description
  s.author = "Orion Henry"
  s.email = "orion@heroku.com"
  s.homepage = "http://github.com/orionz/minion"
  s.rubyforge_project = "minion"
  s.files = FileList["[A-Z]*", "{bin,lib,spec}/**/*"]
  s.add_dependency "amqp", ">= 0.6.7"
  s.add_dependency "bunny", ">= 0.6.0"
  s.add_dependency "json", ">= 1.2.0"
end

Jeweler::RubyforgeTasks.new

desc 'Run specs'
task :spec do
  sh 'bacon -s spec/*_spec.rb'
end

task :default => :spec
