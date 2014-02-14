require "rubygems"
require "bundler/setup"

require "dax"

puts "Building DB."

db = Dax.build_db("database")
puts db
Dax.save_db("database", db)
File.open("database") do |file|
    puts file.read
end
puts "Finished!"


