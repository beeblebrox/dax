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
    @missing_cmd = (options.has_key? :missing_cmd) ? options[:missing_cmd] : nil
    Thread::abort_on_exception = true

    @zthread = Thread.new do
      server_loop
    end
  end
  
  def missing_cmd(&block)
    @missing_cmd = block  
  end
  
  def missing_cmd=(*args, &block)
    @missing_cmd = block
    raise ArgumentError, "Must provide block or nil parameter" if args.length == 0
    raise ArgumentError, "Must provide block or nil parameter" if args[0]
    @missing_cmd = nil
  end
  
  def key=(aes_key)
    @key = aes_key
  end
  
  def handle(command, &block)
      @commands ||= { }
      cmd = command?(command)
      @commands[command.to_sym] = block unless cmd
  end
  
  def command?(command)
    return nil unless @commands
    sym = command.to_sym
    ret = @commands.has_key?(sym)  ? @commands[sym] : nil
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
  
  def send_error msg
    error = { :error => msg }
    msg = JSON.generate(error)
    snd msg
  end
  
  def server_loop
    cnt = 0
    until @shutdown
      cnt = cnt + 1
      begin
        begin
          msg = rcv
        rescue
          log ERROR, "#{cnt} - #{$!.inspect}"
          return
        end
        return if @shutdown
        begin
          msg = JSON.parse(msg, :symbolize_names => true)
        rescue 
          send_error $!.inspect
          next
        end
        op = command? msg[:op] if msg
        params = msg[:params] rescue params = nil
        if op
          begin
            result = op.call params
            snd JSON.generate(:result => result)
          rescue
            send_error "#{$!.inspect}" unless @shutdown
            next
          end
        elsif @missing_cmd
          begin
            result = @missing_cmd.call params
            snd JSON.generate(:result => result)
          rescue
            send_error "#{$!.inspect}" unless @shutdown
            next
          end
        else
          send_error "I don't understand #{msg[:op]}" unless @shutdown
          next
        end
      rescue
       log WARN, "Never expect to catchall: #{$!.inspect}"
      end
    end
  rescue
    @error = "Error while running server, shutting down. (#{$!.inspect})"
    log FATAL, @error
  end
end