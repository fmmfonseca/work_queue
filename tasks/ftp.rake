require 'net/ftp'
require 'pathname'
require 'yaml'
require 'rubygems'
require 'rake'
require 'rake/tasklib'

module Rake

  # = FTPTask
  #
  # == Description
  # A Rake task that transfers local files to an FTP server.
  #
  # == Usage
  #  Rake::FTPTask.new do |t|
  #   t.host = "ftp.example.com"
  #   t.user_name = "user"
  #   t.password = "pass"
  #   t.path = "public_html/"
  #   t.upload_files = FileList["doc/**/*"].to_a
  #  end
  #
  # To avoid hard-coding the connection configuration into the source code, the task can obtain that data from a YAML file.
  #
  #  Rake::FTPTask.new do |t|
  #   t.config_file = "ftp.yml"
  #   t.path = "public_html/"
  #   t.upload_files = FileList["doc/**/*"].to_a
  #  end
  #
  #  # ftp.yml
  #  host = ftp.example.com
  #  user_name = user
  #  password = pass
  #  path = public_html/
  #
  class FTPTask < TaskLib

    ##
    # The name of the main, top level task (default is :ftp).
    #
    attr_accessor :name
    
    ##
    # The file containing the connection configuration (default is nil).
    #
    attr_accessor :config_file

    ##
    # The address of the server (default is nil).
    #
    attr_accessor :host

    ##
    # The user name required to log into the server (default is "anonymous").
    #
    attr_accessor :user_name

    ##
    # The password required for the selected user name (default is nil).
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
    # The boolean to enable progress messages when true (default is false).
    #
    attr_accessor :verbose

    ##
    # Creates a new FTP task with the given name.
    #
    def initialize(name=:ftp)
      @name = name
      @config_file = nil
      @host = nil
      @user_name = "anonymous"
      @password = nil
      @path = ""
      @upload_files = []
      @verbose = false
      @ftp = nil
      @history = {}
      yield self if block_given?
      define
    end

    ##
    # Creates the tasks defined by this task lib.
    #
    def define

      namespace @name do
        desc "Upload files to an FTP account"
        task(:upload) do
          connect
          upload
          disconnect
        end
      end

    end

    private

    ##
    # Reads configuration values from a YAML file.
    #
    def load_config
      config = YAML::load_file(@config_file)
      @host = config["host"] || @host
      @user_name = config["user_name"] || @user_name
      @password = config["password"] || @password
      @path = config["path"] || @path
    end

    ##
    # Establishes the FTP connection.
    #
    def connect
      load_config unless @config_file.nil?
      @ftp = Net::FTP.new(@host, @user_name, @password)
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
    # Creates a directory and all its parent directories in the server, relative to the current working directory.
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

Rake::FTPTask.new do |ftp|
  ftp.config_file = "config/ftp.yml"
  ftp.upload_files = FileList["doc/**/*"].to_a
  ftp.verbose = true
end