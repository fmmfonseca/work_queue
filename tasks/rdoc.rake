require 'rake/rdoctask'

CLEAN.include("doc")

# For a list of all attributes refer to http://rake.rubyforge.org/classes/Rake/RDocTask.html
Rake::RDocTask.new do |rd|
  rd.title = "WorkQueue"
  rd.main = "README.rdoc"
  rd.rdoc_files.include("README.rdoc", "lib/**/*.rb")
  rd.rdoc_dir = "doc"
end