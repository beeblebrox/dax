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

module GState
  @cnt = 0
  def self.cnt 
    @cnt
  end
  
  def self.cnt=(val)
    @cnt = val
  end
end

describe Server do

  around :each do |example|
    begin
    def self.echo_cmd(msg) 
      msg
    end
    port = 4242 + GState.cnt
    GState.cnt = GState.cnt + 1
    @s = Server.new :db => nil, :listen => "tcp://*:#{port}", :key => nil, :missing_cmd => self.method(:echo_cmd)
    @zmq = ZMQ::Context.new
    @socket = @zmq.socket(ZMQ::REQ)
    @socket.setsockopt(ZMQ::RCVTIMEO, 1000)
    @socket.setsockopt(ZMQ::SNDTIMEO, 1000)
    @socket.setsockopt(ZMQ::LINGER, 0)
    @socket.connect  "tcp://127.0.0.1:#{port}"
    example.run
    ensure
     @s.cleanup if @s
    end
  end


  it "creates zmq server" do
    @socket.send_string '{ "op": "any", "params": "yomammy" }'
    msg = ''
    rc = @socket.recv_string msg
    expect(ZMQ::Util.resultcode_ok?(rc)).to be
    expect(msg).to have_json_result("yomammy")
  end
  
  it "creates zmq server, again" do
    @socket.send_string '{ "op": "any", "params": "yomammy" }'
    msg = ''
    rc = @socket.recv_string msg
    expect(ZMQ::Util.resultcode_ok?(rc)).to be
    expect(msg).to have_json_result("yomammy")
  end
  
  it "encrypted zmq server" do
    original_cipher = Crypto.encrypt("mysecret", '{ "op": "any", "params": "yomammy" }')
    @s.key = "mysecret"
    @socket.send_string original_cipher 
    msg = ''
    rc = @socket.recv_string msg
    # Encryption should use different iv each time, thus different cipher result
    # for same values.
    expect(Crypto.decrypt("mysecret", msg)).to have_json_result("yomammy")
    expect(msg).not_to eq original_cipher
    expect(ZMQ::Util.resultcode_ok?(rc)).to be
  end
  
  it "server can shutdown with blocked recieve" do
    # server is actually running, we just attempt to end the test without doing anything.
  end

end