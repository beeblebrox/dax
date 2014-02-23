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
    @zmq = ZMQ::Context.new(1)
    @socket = @zmq.socket(ZMQ::REP)
    @socket.bind(@listen)
    Thread::abort_on_exception = true

    @zthread = Thread.new do
      server_loop
    end
  end

  def handle(command, &block)
      @commands ||= { }
      cmd = command?(command)
      @commands[command.to_sym] = block unless cmd
  end
  
  def command?(command)
    sym = command.to_sym
    ret = @commands.has_key?(sym)  ? @commands[sym] : false
  end
  
  def invoke(command, data)
    return unless @commands
    cmd = command?(command)
    log WARN, "No command #{command}." unless cmd
    return unless cmd
    cmd.call data
  end
  
  def cleanup
    @shutdown = true
    raise @error if @error
    @zthread.join if @zthread
  end

  def context
    @zmq
  end

  def error_check(rc, errno)
    if ZMQ::Util.resultcode_ok?(rc) || errno ==  ZMQ::EAGAIN
      false
    else
      log ERROR, "Operation failed, errno [#{ZMQ::Util.errno}] description [#{ZMQ::Util.error_string}]"
      true
    end
  end
  
  private

  def server_loop
    @socket.setsockopt(ZMQ::LINGER, 0)
    @socket.setsockopt(ZMQ::RCVTIMEO, 1000)
    until @shutdown
      msg = ''
      rc = 0
      errno = 0
      begin 
        rc = @socket.recv_string msg
        errno = ZMQ::Util.errno
        log DEBUG, "Received: #{msg}" unless rc < 0
        break if @shutdown
      end while rc < 0 && errno == ZMQ::EAGAIN
      break if @shutdown
      raise "Could not receive message." if error_check(rc, errno)
      msg = Crypto.decrypt(@key, msg) if @key
      msg = Crypto.encrypt(@key, msg) if @key
      rc = @socket.send_string msg
      errno = ZMQ::Util.errno
      raise "Could not send message." if error_check(rc, errno)
    end
    rescue
      @error = "Error while running server, shutting down. (#{$!.inspect})"
      log FATAL, @error
  end
end