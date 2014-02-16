require "dax/version"
require "json"
require "date"
require "digest/sha1"

module Dax
  
  def self.add_dir(path, db)
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
        add_dir(rname, db)
        next
      end
      next unless File.file? rname
      puts rname
      begin
        File.open(rname, "r") do |file|
          head = file.read((2^20) * 100)
          next if !head
          digest = Digest::SHA1.hexdigest head
          db[:files] += [ { :name => rname, :sha => digest } ]
        end
      rescue => e
       puts e        
      end 
    end
    
  end
  
  def self.build_db(fname)
     db = {}
     File.open(fname, "a+") do |file|
        begin
            db = JSON.parse(file.read(), :symbolize_names => true) 
        rescue => e
            puts e
            puts "Could not read database, creating a new one."
            db =  { :lastmodified => DateTime.now.rfc3339, :files => [ ] }
        end
     end
     db
  end
  
  def Dax.save_db(fname, db)
    File.open(fname, "w") do |file|
      begin
        file.write(JSON.pretty_generate ( db ) )
      rescue => e
        puts e
        puts "Could not save database!"
      end
    end
  end
  
end
