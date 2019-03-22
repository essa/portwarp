
require 'open-uri'
require 'securerandom'
require 'shellwords'
require 'socket'

require 'portwarp/utils'


module PortWarp
  class Server
    include Utils
    def initialize(options)
      @random = options['random']
    end

    def start(base_url)
      random = @random || SecureRandom.hex(8)
      url = base_url + random
      $log.info "url = #{url}"
      start_http(url, :Get) do |http, req|
        http.request req do |response|
          p 1111,response
          response.read_body do |chunk|
            p 2222,chunk
            process_command(chunk)
          end
        end
      end
    end

    def process_command(line)
      a = Shellwords.split(line)
      return unless a[2]
      target_host, target_port = a[2].split(':')
      url1 = a[3]
      url2 = a[4]
      $log.debug "received command #{a.inspect} target=#{target_host}:#{target_port}"
      TCPSocket.open(target_host, target_port) do |sock|
        $log.debug "connected to #{target_host}:#{target_port}"

        threads = piping_to_socket(url1, sock)
        threads += socket_to_piping(sock, url2)

        threads.each { |t| t.join }
      end
    end
  end
end
