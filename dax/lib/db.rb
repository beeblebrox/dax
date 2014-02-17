require "json"
require "date"
require "digest/sha1"

require 'set'
require 'pathname'

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
    read_db
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
    set1.subtract(db.files)
    set1
  end
  
  def files
    @db[:files]  
  end
  
  private

  def refresh_db
   @db = { :lastmodified => DateTime.now.rfc3339, :files => [ ] }
   add_dir @files_location, Pathname.new(@files_location).realpath
  end

  def add_dir(path, originalpath)
    Dir.foreach path do |name|
      next if name == "." 
      next if name == ".."
      rname = nil
      begin
        rname = File.expand_path name, path 
      rescue => e
        puts e.message
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
          @db[:files] += [ { :name => rpath, :sha => digest } ]
        end
      rescue => e
       puts e        
      end 
    end
  end

  def read_db
    @db = { }
    fname = @db_location
    
    File.open(fname, "a+") do |file|
      begin
          @db = JSON.parse(file.read(), :symbolize_names => true) 
      rescue => e
          puts e
          puts "Could not read database, creating a new one."
          @db =  { :lastmodified => DateTime.now.rfc3339, :files => [ ] }
      end
    end
  end
  
  def save_db
    fname = @db_location
    File.open(fname, "w") do |file|
      begin
        file.write(JSON.pretty_generate ( @db ) )
      rescue => e
        puts e
        puts "Could not save database!"
      end
    end
  end
end