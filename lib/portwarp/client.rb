
require 'socket'
require 'net/https'
require 'securerandom'

require 'portwarp/utils'

module PortWarp
  class Client
    include Utils

    def initialize(options)
    end

    def start(ctl_pipe, port, target)
      p ctl_pipe, port, target

      sock = start_server(port.to_i)
      r1 = SecureRandom.hex(8)
      r2 = SecureRandom.hex(8)
      u = URI.parse(ctl_pipe)
      url1 = "#{ctl_pipe}_#{r1}"
      url2 = "#{ctl_pipe}_#{r2}"
      # url1 = "http://localhost:8080/#{r1}"
      # url2 = "http://localhost:8080/#{r2}"

      # IO.popen("curl -T - #{ctl_pipe}", "w") do |io|
      #   $log.debug "start proxy #{target} #{url1} #{url2}"
      #   io.puts "start proxy #{target} #{url1} #{url2}"
      # end

      i_pipe,o_pipe = IO.pipe
      t0 = Thread.start do
        $log.debug "ctl pipe sending start"
        start_http(ctl_pipe, :Put) do |http, req|
          req.body_stream = i_pipe
          req["Transfer-Encoding"] = "chunked"
          http.request(req)
        end
        $log.debug "ctl pipe sending end"
      end
      $log.debug "start proxy #{target} #{url1} #{url2}"
      o_pipe.puts "start proxy #{target} #{url1} #{url2}"
      #o_pipe.flush
      o_pipe.close

      threads = socket_to_piping(sock, url1)
      threads += piping_to_socket(url2, sock)

      threads.each { |t| t.join }
    end

    def start_server(port)
      $log.debug "start listening #{port}"
      server = TCPServer.open(port)
      s = server.accept
      $log.debug "accepted a connection"
      s
    end
  end
end
