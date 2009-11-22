require 'rubygems'
require 'rake'
require 'rake/clean'

# Load all rakefile extensions
Dir["#{File.dirname(__FILE__)}/tasks/*.rake"].each { |ext| load ext }

# Set default task
task :default => ["test:unit"]