require 'rdoc/task'

CLEAN.include("doc")

# For a list of all attributes refer to http://rake.rubyforge.org/classes/Rake/RDocTask.html
Rake::RDocTask.new do |t|
  t.title = "work_queue-#{WorkQueue::VERSION} Documentation"
  t.main = "README.rdoc"
  t.rdoc_files.include("README.rdoc", "lib/**/*.rb")
  t.rdoc_dir = "doc"
end