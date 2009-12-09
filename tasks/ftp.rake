require 'net/ftp'
require 'pathname'
require 'yaml'
require 'rubygems'
require 'rake'
require 'rake/tasklib'

module Rake
	
	##
	# A Rake task that transfers local files to an FTP server.
	#
	class FTPTask < TaskLib
		
		##
		# The address of the server (default is nil).
		#
		attr_accessor :host
		
		##
		# The user name required to log into the server (default is "").
		#
		attr_accessor :user_name
		
		##
		# The password required for the selected user name (default is "").
		#
		attr_accessor :password
		
		##
		# The (remote) base directory (default is "").
		#
		attr_accessor :path
		
		##
		# The array of files to be included in the FTP upload (default is []).
		#
		attr_accessor :upload_files
		
		##
		# A flag that enables printing debug messages to standard output when true (default is false).
		#
		attr_accessor :verbose
		
		##
		# Creates a new FTP task.
		#
		def initialize(config_file=nil)
			@host = nil
			@user_name = ""
			@password = ""
			@path = ""
			@upload_files = []
			@verbose = false
			@ftp = nil
			@history = {}
			load_config(config_file) unless config_file.nil?
			yield self if block_given?
			define
		end
		
		##
		# Creates the tasks defined by this task lib.
		#
		def define
			desc "Upload files to an FTP account"
			task(:upload) do
				connect
				upload
				disconnect
			end
		end
		
		private
		
		##
		# Read configuration values from a YAML file.
		#
		def load_config(file)
			config = YAML::load_file(file)
			@host = config["host"]
			@username = config["user_name"]
			@password = config["password"]
			@path = config["path"]
		end
		
		##
		# Establishes an FTP connection.
		#
		def connect
			@ftp = Net::FTP.new(@host, @username, @password)
			puts "Connected to #{@host}" if @verbose
			puts "Using #{@ftp.binary ? "binary" : "text"} mode to transfer files" if @verbose
			unless @path.nil? or @path.empty?
				make_dirs(@path)
				@ftp.chdir(@path)
				puts "The working directory is now #{@ftp.getdir}" if @verbose
			end
		end
		
		##
		# Closes the FTP connection. Further remote operations are impossible. 
		#
		def disconnect
			@ftp.close
			puts "Disconnected" if @verbose
		end
		
		##
		# Iterates through the array of files.
		#
		def upload
			puts "Uploading #{@upload_files.length} files..." if @verbose
			@upload_files.each do |entry|
				if File.directory?(entry)
					make_dirs(entry)
				else
					put_file(entry)
				end
			end
		end
		
		##
		# Transfers a local file to the server, relative to the current working directory.
		#
		def put_file(name)
			puts "Uploading file #{name}" if @verbose
			path = File.dirname(name)
			make_dirs(path)
			@ftp.put(name,name)
		end
		
		##
		# Creates a directory and all its parent directories, relative to the current working directory.
		#
		def make_dirs(name)
			Pathname.new(name).descend do |dir|
				if @history[dir].nil?
					@history[dir] = true
					puts "Creating directory #{dir}" if @verbose
					@ftp.mkdir(dir) rescue nil
				end
			end
		end
		
	end
	
end

Rake::FTPTask.new("config/ftp.yml") do |ftp|
	ftp.upload_files = FileList["doc/**/*"].to_a
	ftp.verbose = true
end