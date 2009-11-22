require 'rake/testtask'

namespace(:test) do

	# For a list of all attributes refer to http://rake.rubyforge.org/classes/Rake/TestTask.html
	Rake::TestTask.new(:unit) do |t|
		t.libs << "test"
		t.test_files = FileList['test/tc_*.rb']
		t.verbose = true
		t.warning = true
	end

	desc "Run tests on multiple ruby versions"
	task(:compatibility) do
		versions = %w[1.8.6 1.8.7 1.9.1 jruby]
		system <<-CMD
			bash -c 'source ~/.rvm/scripts/rvm;
					 rvm #{versions.join(',')} rake test:unit'
		CMD
	end

end