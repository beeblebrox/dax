require 'rubygems'
require 'bundler/setup'
require 'rspec/expectations'
require 'ffi-rzmq'

describe ZMQ do

  it "provides EAGAIN for RECV timeout" do
    zmq = ZMQ::Context.new(50)
    socket = zmq.socket(ZMQ::REP)
    socket.bind('tcp://*:4242')
    
    socket.setsockopt(ZMQ::LINGER, 1000)
    socket.setsockopt(ZMQ::RCVTIMEO, 1000)
    # Will timeout due to socket option
    msg = ''
    rc = socket.recv_string msg
    expect(rc).to be == -1
    # As far as I can tell, this should be the correct error
    expect(ZMQ::Util.errno).to be == ZMQ::EAGAIN
  end
  
  
  it "always provides EAGAIN for RECV timeout" do
    zmq = ZMQ::Context.new(50)
    socket = zmq.socket(ZMQ::REP)
    socket.bind('tcp://*:4242')
    
    socket.setsockopt(ZMQ::LINGER, 1000)
    socket.setsockopt(ZMQ::RCVTIMEO, 1000)
    # Will timeout due to socket option
    msg = ''
    Thread.new do
      5.times do
        rc = socket.recv_string msg
        expect(rc).to be == -1
        # As far as I can tell, this should be the correct error
        expect(ZMQ::Util.errno).to be == ZMQ::EAGAIN
      end
    end.join
  end

 it "always provides same errorno" do
    zmq = ZMQ::Context.new(50)
    socket = zmq.socket(ZMQ::REP)
    socket.bind('tcp://*:4242')
    
    socket.setsockopt(ZMQ::LINGER, 1000)
    socket.setsockopt(ZMQ::RCVTIMEO, 1000)
    # Will timeout due to socket option
    msg = ''
    rc = socket.recv_string msg
    expect(rc).to be == -1
    # As far as I can tell, this should be the correct error
    expect(ZMQ::Util.errno).to be == ZMQ::EAGAIN
    # This is suprising if it fails
    100.times do
      expect(ZMQ::Util.errno).to be == ZMQ::EAGAIN
    end
  end
end