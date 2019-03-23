
require 'socket'
require 'net/https'
require 'securerandom'

require 'portwarp/utils'

module PortWarp
  class Client
    include Utils

    attr_reader :cmd_pipe
    def initialize(options)
    end

    def start(ctl_pipe_url, port, target, *cmds)
      $log.debug "start listening #{port}"
      server = TCPServer.open(port)
      start_ctl_pipe_connection(ctl_pipe_url)

      if cmds.size > 0
        $log.info "started with a command #{cmds}"
        Thread.start do
          sock = server.accept
          $log.debug "accepted a connection"
          start_forwarding(ctl_pipe_url, sock, port, target)
        end
        $log.info "invoking a command #{cmds.join(' ')}"
        system cmds.join(' ')
      else
        while true
          sock = server.accept
          $log.debug "accepted a connection"
          Thread.start do
            start_forwarding(ctl_pipe_url, sock, port, target)
          end
        end
      end
    end

    def start_ctl_pipe_connection(ctl_pipe_url)
      i_pipe,o_pipe = IO.pipe
      t0 = Thread.start do
        $log.debug "ctl pipe sending start"
        start_http(ctl_pipe_url, :Put) do |http, req|
          req.body_stream = i_pipe
          req["Transfer-Encoding"] = "chunked"
          http.request(req)
        end
        $log.debug "ctl pipe sending end"
      end
      @cmd_pipe = o_pipe
    end

    def start_forwarding(ctl_pipe_url, sock, port, target)
      $log.info "start forwarding to #{target}"
      r1 = SecureRandom.hex(8)
      r2 = SecureRandom.hex(8)
      u = URI.parse(ctl_pipe_url)
      url1 = "#{ctl_pipe_url}_#{r1}"
      url2 = "#{ctl_pipe_url}_#{r2}"

      $log.debug "start forwarder #{target} #{url1} #{url2}"
      cmd_pipe.puts "start forwarder #{target} #{url1} #{url2}"
      cmd_pipe.flush

      threads = socket_to_piping(sock, url1)
      threads += piping_to_socket(url2, sock)

      threads.each { |t| t.join }
      $log.info "end of forwarding to #{target}"
    end
  end
end
