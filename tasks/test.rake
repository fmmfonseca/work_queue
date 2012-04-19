require 'rake/testtask'

namespace(:test) do
  # For a list of all attributes refer to http://rake.rubyforge.org/classes/Rake/TestTask.html
  Rake::TestTask.new(:unit) do |t|
    t.libs << "test"
    t.test_files = FileList['test/tc_*.rb']
    t.verbose = true
    t.warning = true
  end
end