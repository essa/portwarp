
require 'open-uri'
require 'securerandom'
require 'shellwords'
require 'socket'

require 'portwarp/utils'


module PortWarp
  class Server
    include Utils
    def initialize(options)
      @secret_key = options['secret-key']
    end

    def start(base_url)
      secret_key = @secret_key || SecureRandom.hex(8)
      url = base_url + secret_key
      $log.info "server start url = #{url}"
      start_http(url, :Get) do |http, req|
        $log.debug "server started receiving"
        i_pipe, o_pipe = IO.pipe
        t1 = Thread.start do
          begin
            http.request req do |response|
              response.read_body do |chunk|
                $log.debug "server received #{chunk.inspect} "
                o_pipe.write chunk
                o_pipe.flush
              end
            end
          rescue Errno::EBADF
          end
        end
        while line = i_pipe.gets
          ret = process_command(line)
          break unless ret
        end
      end
    end

    def process_command(line)
      a = Shellwords.split(line)
      $log.info "received command #{a.inspect}"
      case a[0..1]
      when %w(start forwarder)
        return unless a[2]
        Thread.start do
          do_forwarding(*a[2..4])
        end
        true
      when ['terminate']
        $log.info 'terminating...'
        exit 0
      else
        $log.warn "unknown command #{a[0]} #{a[1]}"
        false
      end
    end

    def do_forwarding(target, url1, url2)
      target_host, target_port = target.split(':')
      $log.debug "connecting to #{target_host}:#{target_port}"
      TCPSocket.open(target_host, target_port) do |sock|
        $log.info "connected to #{target_host}:#{target_port}"

        $log.debug "forwarding #{url1} -> #{target}"
        threads = piping_to_socket(url1, sock)
        $log.debug "forwarding #{target} -> #{url2}"
        threads += socket_to_piping(sock, url2)

        threads.each { |t| t.join }
      end
    end
  end
end
