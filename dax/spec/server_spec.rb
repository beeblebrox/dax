require 'spec_helper'
require 'ffi-rzmq'

describe "server api" do
  
  before :each do
    @server = Server.new :db => nil, :listen => "tcp://*:1234", :key => nil
  end
  
  after :each do
    @server.cleanup
  end
  
  it "can add single command" do
    @server.handle "poke" do |data|
      "poke #{data}"
    end
    cmd = @server.command? "poke"
    expect(cmd).to be
    expect(cmd.call "face").to eq "poke face"
  end
  
  it "can invoke added command" do
    @server.handle "poke" do |data|
      "poke #{data}"
    end
    expect(@server.invoke("poke", "face")).to eq "poke face"
  end

end

describe Server do

  it "creates zmq server" do
    begin
      s = Server.new :db => nil, :listen => "tcp://*:4242", :key => nil
      zmq = ZMQ::Context.new
      socket = zmq.socket(ZMQ::REQ)
      socket.setsockopt(ZMQ::RCVTIMEO, 1000)
      socket.setsockopt(ZMQ::SNDTIMEO, 1000)
      socket.setsockopt(ZMQ::LINGER, 0)
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
  
  it "creates zmq server, again" do
    begin
      s = Server.new :db => nil, :listen => "tcp://*:4243", :key => nil
      zmq = ZMQ::Context.new
      socket = zmq.socket(ZMQ::REQ)
      socket.setsockopt(ZMQ::RCVTIMEO, 1000)
      socket.setsockopt(ZMQ::SNDTIMEO, 1000)
      socket.setsockopt(ZMQ::LINGER, 0)
      socket.connect  "tcp://127.0.0.1:4243"
      socket.send_string "yomammy"
      msg = ''
      rc = socket.recv_string msg
      expect(ZMQ::Util.resultcode_ok?(rc)).to be
      expect(msg).to be == "yomammy"
    ensure
     s.cleanup if s
    end
  end
  
  it "encrypted zmq server" do
    begin
      s = Server.new :db => nil, :listen => "tcp://*:4244", :key => "mysecret"
      zmq = ZMQ::Context.new
      socket = zmq.socket(ZMQ::REQ)
      socket.setsockopt(ZMQ::RCVTIMEO, 1000)
      socket.setsockopt(ZMQ::SNDTIMEO, 1000)
      socket.connect  "tcp://127.0.0.1:4244"
      original_cipher = Crypto.encrypt("mysecret", "yomammy")
      socket.send_string original_cipher 
      msg = ''
      rc = socket.recv_string msg
      # Encryption should use different iv each time, thus different cipher result
      # for same values.
      expect(Crypto.decrypt("mysecret", msg)).to eq "yomammy"
      expect(msg).not_to eq original_cipher
      expect(ZMQ::Util.resultcode_ok?(rc)).to be
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