require 'rubygems'
require 'bundler/setup'

require "json"
require "date"
require "digest/sha1"
require 'set'
require 'pathname'

require 'listen'

class DB
  def initialize(options=nil)
    raise ArgumentError, "Need :db_location and :files_location." unless options.respond_to? 'has_key?'
    raise ArgumentError, "Database location (:db_location) not provided." if ! options.has_key? :db_location
    raise ArgumentError, "Files location (:files_location) not provided." if ! options.has_key? :files_location
    @db_location = options[:db_location]
    @files_location = options[:files_location]
    @initialized = false
  end
  
  def init
    return if @initialized
    @initialized = true
    read_db
    @listener = Listen.to(@files_location) do |modified, added, removed|
      begin
        modified.each { |file| refresh_file file }
        added.each { |file| refresh_file file }
      rescue
        puts $!.inspect, $@
      end
    end
    @listener.start
    puts "Started listener"
  end

  def cleanup
    return unless @initialized
    @listener.stop
    puts "Stopped listener."
  end
  
  def refresh
    init
    refresh_db
  end
  
  def save
    init
    save_db  
  end
  
  def additional_compared_to (db)
    set1 = @db[:files].to_set
    set1.subtract(db.files.to_set)
  end
  
  def files
    @db[:files]  
  end
  
  private

  def refresh_db
   @db = { :lastmodified => DateTime.now.rfc3339, :files => [ ] }
   add_dir @files_location, Pathname.new(@files_location).realpath
  end
  
  def refresh_file(aname)
    File.open(aname, "r") do |file|
      head = file.read((2^20) * 100)
      next if !head
      digest = Digest::SHA1.hexdigest head
    end
    result = nil
    curdir = Pathanme.new(@files_location).expand_path
    name = Pathname.new(rname).relative_path_from(curdir)
    @db[:files].index do |hash|
      if hash[:name] == name
        result = hash
        true
      else
        false
      end
    end
    
    if result
      # Already exists, refresh
      result[:sha] = digest 
    else
      #new entry
      @db[:files] += [ { :name => name,
                         :sha => digest } ]
    end      
  rescue
    puts $!.inspect, $@
  end 

  def add_dir(path, originalpath)
    Dir.foreach path do |name|
      next if name == "." 
      next if name == ".."
      rname = nil
      begin
        rname = File.expand_path name, path 
      rescue
        puts $!.inspect, $@
        next
      end
      next unless rname
      if Dir.exists? rname
        add_dir(rname, originalpath)
        next
      end
      next unless File.file? rname
      
      rpath = Pathname.new(rname)
      rpath = rpath.relative_path_from(originalpath).to_s
      begin
        File.open(rname, "r") do |file|
          head = file.read((2^20) * 100)
          next if !head
          digest = Digest::SHA1.hexdigest head
          @db[:files] += [ { :name => rpath,
                             :sha => digest } ]
        end
      rescue
        puts $!.inspect, $@
      end 
    end
  end

  def read_db
    @db = { }
    fname = @db_location
    
    File.open(fname, "a+") do |file|
      begin
          @db = JSON.parse(file.read(), :symbolize_names => true) 
      rescue
        puts $!.inspect
        @db =  { :lastmodified => DateTime.now.rfc3339, :files => [ ] }
      end
    end
  end
  
  def save_db
    fname = @db_location
    File.open(fname, "w") do |file|
      begin
        file.write(JSON.pretty_generate ( @db ) )
      rescue
        puts $!.inspect
        puts "Could not save database!"
      end
    end
  end
end