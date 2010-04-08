require 'rubygems'
require 'lib/support/gateway_support'
require 'lib/active_merchant'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "smulube-activemerchant"
    gemspec.version = ActiveMerchant::VERSION
    gemspec.summary = 'Framework and tools for dealing with credit card transactions.'
    gemspec.description  = 'Active Merchant is a simple payment abstraction library used in and sponsored by Shopify. It is written by Tobias Luetke, Cody Fauser, and contributors. The aim of the project is to feel natural to Ruby users and to abstract as many parts as possible away from the user to offer a consistent interface across all supported gateways.'
    gemspec.email = "tobi@leetsoft.com"
    gemspec.authors = ["Tobias Luetke", "Cody Fauser", "Dennis Thiesen", "Sam Mulube"]
    gemspec.homepage = 'http://activemerchant.org/'
    gemspec.add_dependency('activesupport', '>= 2.3.2')
    gemspec.add_dependency('builder', '>= 2.0.0')
  
    gemspec.signing_key = ENV['GEM_PRIVATE_KEY']
    gemspec.cert_chain  = ['gem-public_cert.pem']
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: gem install jeweler"
end

require 'rake/testtask'
namespace :test do
  Rake::TestTask.new(:units) do |test|
    test.libs << 'lib' << 'test'
    test.pattern = 'test/unit/**/*_test.rb'
    test.verbose = true
    test.ruby_opts << '-rubygems'
  end

  Rake::TestTask.new(:remote) do |test|
    test.libs << 'lib' << 'test'
    test.pattern = 'test/remote/**/*_test.rb'
    test.verbose = true
    test.ruby_opts << '-rubygems'
  end
end

desc "Run the unit test suite"
task :default => 'test:units'

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title    = "ActiveMerchant library"
  rdoc.options << '--line-numbers' << '--inline-source' << '--main=README.rdoc'
  rdoc.rdoc_files.include('README.rdoc', 'CHANGELOG')
  rdoc.rdoc_files.include('lib/**/*.rb')
  rdoc.rdoc_files.exclude('lib/tasks')
end

require 'rake/clean'
CLEAN.include("pkg")

namespace :gateways do
  desc 'Print the currently supported gateways'
  task :print do
    support = GatewaySupport.new
    support.to_s
  end
  
  namespace :print do
    desc 'Print the currently supported gateways in RDoc format'
    task :rdoc do
      support = GatewaySupport.new
      support.to_rdoc
    end
  
    desc 'Print the currently supported gateways in Textile format'
    task :textile do
      support = GatewaySupport.new
      support.to_textile
    end
    
    desc 'Print the gateway functionality supported by each gateway'
    task :features do
      support = GatewaySupport.new
      support.features
    end
  end
end
