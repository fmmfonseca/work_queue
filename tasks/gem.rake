require 'rake/gempackagetask'
require 'lib/work_queue'

CLEAN.include("pkg")

# For a list of all attributes refer to http://docs.rubygems.org/read/chapter/20
spec = Gem::Specification.new do |s|
  s.name = "work_queue"
  s.version = WorkQueue::VERSION
  s.summary = "A tunable work queue, designed to coordinate work between a producer and a pool of worker threads."
  s.homepage = "http://github.com/fmmfonseca/work_queue"
  s.author = "Miguel Fonseca"
  s.email = "fmmfonseca@gmail.com"

  s.required_ruby_version = ">= 1.8.6"
  s.files = FileList["LICENSE", "Rakefile", "README.rdoc", "tasks/*.rake", "lib/**/*.rb", "test/tc_*.rb"].to_a
  s.test_files = Dir.glob("test/tc_*.rb")
  s.has_rdoc = true
  s.extra_rdoc_files = %w[README.rdoc]
  s.rdoc_options = %w[--line-numbers --inline-source --title WorkQueue --main README.rdoc]
end

# For a list of all attributes refer to http://rake.rubyforge.org/classes/Rake/PackageTask.html
Rake::GemPackageTask.new(spec) do |p|
  p.need_zip = true
end