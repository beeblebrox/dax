require 'spec_helper'
require 'ffi-rzmq'

describe Server do

  it "creates zmq server" do
    begin
      s = Server.new :db => nil, :listen => "tcp://*:4242", :key => nil
      zmq = ZMQ::Context.new
      socket = zmq.socket(ZMQ::REQ)
      socket.connect  "tcp://127.0.0.1:4242"
      socket.send_string "yomammy"
      msg = ''
      rc = socket.recv_string msg
      expect(ZMQ::Util.resultcode_ok?(rc)).to be
      expect(msg).to be == "yomammy"
    ensure
     s.cleanup if s
    end
  end
  
  it "server can shutdown with blocked recieve" do
    begin
      s = Server.new :db => nil, :listen => "tcp://*:4242", :key => nil
      sleep 5
      s.cleanup
    end
  end

end