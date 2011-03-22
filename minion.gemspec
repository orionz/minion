# encoding: utf-8
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require "minion/version"

Gem::Specification.new do |s|
  s.name = %q{minion}
  s.version = Minion::VERSION
  s.platform = Gem::Platform::RUBY

  s.required_rubygems_version = ">= 1.3.6"
  s.authors = ["Orion Henry"]
  s.date = %q{2010-07-28}
  s.description = %q{Super simple job queue over AMQP}
  s.email = %q{orion@heroku.com}
  s.homepage = %q{http://github.com/orionz/minion}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_path = "lib"
  s.rubyforge_project = %q{minion}
  s.rubygems_version = %q{1.3.6}
  s.summary = %q{Super simple job queue over AMQP}

  s.extra_rdoc_files = [ "README.rdoc" ]
  s.files = Dir.glob("lib/**/*") + %w(LICENSE README.rdoc Rakefile)
  s.test_files = Dir.glob("spec/**/*") + Dir.glob("examples/*")

  s.add_runtime_dependency("amqp", [">= 0.7.1"])
  s.add_runtime_dependency("bunny", [">= 0.6.0"])
  s.add_runtime_dependency("json", [">= 1.2.0"])

  s.add_development_dependency("mocha", ["= 0.9.8"])
  s.add_development_dependency("rspec", ["~> 2.4"])
  s.add_development_dependency("watchr", ["~> 0.6"])
end
