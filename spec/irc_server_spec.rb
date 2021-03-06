require 'spec_helper'
require 'tkellem/irc_server'

include Tkellem

describe Bouncer, "connection" do
  before do
    EM.stub!(:add_timer).and_return(nil)
  end

  def make_server
    b = Bouncer.new(NetworkUser.new(:user => User.new(:username => 'speccer'), :network => Network.new))
    b
  end

  def send_welcome(s, &just_before_last)
    s.should_receive(:send_msg).with("USER speccer somehost tkellem :speccer")
    s.should_receive(:send_msg).with("NICK speccer")
    s.should_receive(:send_msg).with("AWAY :Away")
    s.connection_established(nil)
    s.server_msg(IrcMessage.parse("001 blah blah"))
    s.server_msg(IrcMessage.parse("002 more blah"))
    s.server_msg(IrcMessage.parse("003 even more blah"))
    just_before_last && just_before_last.call
    s.server_msg(IrcMessage.parse("376 :end of MOTD"))
  end

  def connected_server
    s = make_server
    send_welcome(s)
    s.connected?.should be_true
    s
  end

  it "should connect to the server on creation" do
    s = make_server
    s.connected?.should_not be_true
    s.should_receive(:send_msg).with("USER speccer somehost tkellem :speccer")
    s.should_receive(:send_msg).with("NICK speccer")
    s.should_receive(:send_msg).with("AWAY :Away")
    s.connection_established(nil)
  end

  it "should pong" do
    s = connected_server
    s.should_receive(:send_msg).with("PONG tkellem!tkellem :HAI")
    s.server_msg(IrcMessage.parse(":speccer!test@host ping :HAI"))
  end

  def tk_server
    @tk_server ||= TkellemServer.new
  end

  def network_user(opts = {})
    opts[:user] ||= @user ||= User.create!(:username => 'speccer', :password => 'test123')
    opts[:network] ||= @network ||= Network.create!(:name => 'localhost')
    @network_user ||= NetworkUser.create!(opts)
  end

  def bouncer(opts = {})
    tk_server
    network_user
    @bouncer = @tk_server.bouncers.values.last
    if opts[:connect]
      @server_conn = em(IrcServerConnection).new(@bouncer, false)
      @server_conn.stub!(:send_data)
      @bouncer.connection_established(@server_conn)
      @bouncer.send :ready!
    end
    @bouncer
  end

  def client_connection(opts = {})
    @client ||= em(BouncerConnection).new(tk_server, false)
    if opts[:connect]
    end
    @client
  end

  it "should force the client nick on connect" do
    network_user(:nick => 'mynick')
    bouncer(:connect => true)
    @bouncer.server_msg(m ":mynick JOIN #t1")
    client_connection
    @client.should_receive(:send_msg).with(":some_other_nick NICK mynick")
    @client.should_receive(:send_msg).with(":mynick JOIN #t1")
    @client.receive_line("PASS test123")
    @client.receive_line("NICK some_other_nick")
    @client.receive_line("USER #{@user.username}@#{@network.name} a b :c")
  end
end
