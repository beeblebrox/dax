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
  
end