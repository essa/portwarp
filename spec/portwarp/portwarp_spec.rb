
require 'spec_helper'
require 'logger'
require 'portwarp/server'
require 'portwarp/client'

describe 'portwarp' do
  
  ECHO_PORT = 10000
  before do
    @echo_server = fork do
      server = TCPServer.open(ECHO_PORT)
      while true
        s = server.accept
        Thread.start(s) do |echo_sock|
          begin
            while true
              buf = echo_sock.readpartial(1024)
              echo_sock.write buf
              echo_sock.flush
            end
          rescue EOFError
            p $!
          end
        end
      end
    end
  end

  after do
    Process.kill(:KILL, @echo_server)
  end

  it 'should echo direct' do
    TCPSocket.open('localhost', ECHO_PORT) do |sock|
      sock.write 'abc'
      sock.flush
      expect(sock.readpartial(3)).to eq('abc')
    end
  end

  context 'with piping server' do
    PIPING_URL = "http://localhost:8080/"
    before do
      @piping_server = fork do
        exec 'piping-server --enable-log=false'
      end
    end

    after do
      Process.kill(:KILL, @piping_server)
    end

    context 'with portwarp server' do
      class Logger::FormatWithTid < Logger::Formatter
        DATETIME_FORMAT = "%m/%d %H:%M:%S"
        #
        def call(severity, timestamp, progname, msg)
          pid = $$
          tid = "%X" % Thread.current.object_id
          "[#{timestamp.strftime(DATETIME_FORMAT)}.#{'%06d' % timestamp.usec.to_s}] (#{pid}/#{tid}) #{severity} -- : #{String === msg ? msg : msg.inspect}\n"
        end
      end

      let(:ctl_pipe) { 'pipetest' }
      before do
        $log = Logger.new(STDOUT)
        $log.formatter = Logger::FormatWithTid.new
        $log.level = Logger::DEBUG
        @portwarp_server = fork do
          PortWarp::Server.new({'random' => ctl_pipe}).start(PIPING_URL)
        end
      end

      after do
        Process.kill(:KILL, @portwarp_server)
      end

      context 'with portwarp client' do
        FORWARDING_PORT = 10010
        before do
          @portwarp_client = fork do
            PortWarp::Client.new({}).start("#{PIPING_URL}#{ctl_pipe}", FORWARDING_PORT, "localhost:#{ECHO_PORT}")
          end
        end

        after do
          Process.kill(:KILL, @portwarp_client)
        end

        it 'should echo through portwarp' do
          sleep 3
          5.times do |n|
            begin
              TCPSocket.open('localhost', FORWARDING_PORT) do |sock|
                sock.write 'abcd'
                sock.flush
                expect(sock.readpartial(4)).to eq('abcd')
                sock.write 'xyz123'
                sock.flush
                expect(sock.readpartial(6)).to eq('xyz123')
              end
              break
            rescue Errno::ECONNREFUSED
              sleep 0.1 * n
            end
          end
        end
      end
    end
  end
end


