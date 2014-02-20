require 'rubygems'
require 'bundler/setup'

require "json"
require "date"
require "digest/sha1"
require 'logger'
require 'ffi-rzmq'

class Server < Logger::Application
  def initialize(options=nil)
    super("Dax::Server")
    self.level = Logger::INFO
    raise ArgumentError, "Need :db, :port, and :key" unless options.respond_to? 'has_key?'
    raise ArgumentError, "db instance (:db) not provided." if ! options.has_key? :db
    raise ArgumentError, "Listen uri (:listen) not provided." if ! options.has_key? :listen
    raise ArgumentError, "AES key (:key) not provided." if ! options.has_key? :key
    @db = options[:db]
    @listen = options[:listen]
    @key = options[:key]

    @zmq = ZMQ::Context.new(50)
    @socket = @zmq.socket(ZMQ::REP)
    @socket.bind(@listen)

    @zthread = Thread.new do
      msg = ''
      puts "reading"
      @socket.recv_string msg rescue puts $!.inspect, $@
      puts "writing"
      @socket.send_string msg rescue puts $!.inspect, $@
    end
  end

  def cleanup
  end

  def context
    @zmq
  end

  def error_check(rc)
    if ZMQ::Util.resultcode_ok?(rc)
      false
    else
      STDERR.puts "Operation failed, errno [#{ZMQ::Util.errno}] description [#{ZMQ::Util.error_string}]"
      caller(1).each { |callstack| STDERR.puts(callstack) }
      true
    end
  end
  
end