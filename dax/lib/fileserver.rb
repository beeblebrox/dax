require 'rubygems'
require 'bundler/setup'

require 'server'

class Fileserver

def initialize(*args)
  raise ArgumentError, "Must contain an option hash." unless (args.length == 1 && args.responds_to? :keys
  raise ArgumentError, "db instance (:db) not provided." if ! options.has_key? :db
  
  defaults = { :listen => "tcp://*:4242", :key => nil }
  options = defaults.merge args[0]
  @server = Server.new options
  @db = options[:db]
  @files = options[:files]
  @server.handle 'get' do |md5|
    raise ArgumentError "Must supply checksum." unless (md5 && md5.responds_to :to_s)
    md5 = md5.to_s
  end
  
end
  
end
