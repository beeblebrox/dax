require "dax/version"
require "json"
require "date"
require "digest/sha1"

module Dax
  
  def self.add_dir(path, db)
    Dir.foreach path do |name|
      next if name == "." || name == ".."
      rname = File.realdirpath name
      if Dir.exists? rname
        add_dir(rname, db)
        next
      end
      next if ! File.readable? rname
      File.open(rname, "r") do |file|
        head = file.read((2^20) * 100)
        next if !head
        digest = Digest::SHA1.hexdigest head
        db[:files] += [ { :name => rname, :sha => digest } ]
      end
      
    end
    
  end
  
  def self.build_db(fname)
     db = {}
     File.open(fname, "a+") do |file|
        begin
            db = JSON.parse(file.read(), symbolize_names => true) 
        rescue => e
            puts e
            puts "Could not read database, creating a new one."
            db =  { :lastmodified => DateTime.now.rfc3339, :files => [ ] }
        end
     end
     self.add_dir(".", db)
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
