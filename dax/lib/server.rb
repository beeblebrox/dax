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
    @socket.setsockopt(ZMQ::LINGER, 0)
    @socket.setsockopt(ZMQ::RCVTIMEO, 1000)
    @socket.setsockopt(ZMQ::SNDTIMEO, 1000)

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

  def snd(msg)
    msg = Crypto.encrypt(@key, msg) if @key
    rc = @socket.send_string msg
    errno = ZMQ::Util.errno
    raise "Could not send message." if error_check(rc, errno)
  end

  def rcv
    msg = ''
    begin 
      rc = @socket.recv_string msg
      errno = ZMQ::Util.errno
      log DEBUG, "Received: #{msg}" unless rc < 0
      return if @shutdown
    end while rc < 0 && errno == ZMQ::EAGAIN
    return if @shutdown
    raise "Could not receive message." if error_check(rc, errno)
    msg = Crypto.decrypt(@key, msg) if @key
    msg
  end
  
  def server_loop
    until @shutdown
      begin
        msg = rcv
        return if @shutdown
        #JSON.parse(msg, :symbolize_names => true) 
        snd msg
      rescue
      end
    end
    rescue
      @error = "Error while running server, shutting down. (#{$!.inspect})"
      log FATAL, @error
    ensure
  end
end