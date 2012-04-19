require 'rubygems/package_task'

CLEAN.include("pkg")

# For a list of all attributes refer to http://rubygems.rubyforge.org/rubygems-update/Gem/Specification.html
spec = Gem::Specification.new do |s|
  s.name = "work_queue"
  s.version = WorkQueue::VERSION
  s.summary = "A tunable work queue, designed to coordinate work between a producer and a pool of worker threads."
  s.homepage = "http://github.com/fmmfonseca/work_queue"
  s.author = "Miguel Fonseca"
  s.email = "contact@miguelfonseca.com"

  s.required_ruby_version = ">= 1.8.7"
  s.files = FileList["LICENSE", "Rakefile", "README.rdoc", "tasks/test.rake", "lib/**/*.rb", "test/tc_*.rb"].to_a
  s.test_files = Dir.glob("test/tc_*.rb")
  s.has_rdoc = true
  s.extra_rdoc_files = %w[README.rdoc LICENSE]
  s.rdoc_options = %w[--line-numbers --inline-source --main README.rdoc]
end

# For a list of all attributes refer to http://rubygems.rubyforge.org/rubygems-update/Gem/PackageTask.html
Gem::PackageTask.new(spec) do |t|
  t.need_zip = true
end