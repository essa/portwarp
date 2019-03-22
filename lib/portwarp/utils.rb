
require 'net/https'

module PortWarp
  module Utils
    def start_http(url_str, verb, &block)
      url = URI.parse(url_str)
      #p url.scheme, url.host, url.port, url.path
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true if url.scheme == 'https'
      # http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      5.times do
        begin
          http.start  do |http|
            v = Net::HTTP.const_get(verb)
            req = v.new(url.path)
            block.call(http, req)
          end
        rescue Errno::ECONNREFUSED
          p $!
          sleep 1
        end
      end
    end

    def socket_to_piping(sock, url)
      i_pipe, o_pipe = IO.pipe
      t1 = Thread.start do
        while true
          buf = sock.readpartial(1024)
          o_pipe.write buf
          o_pipe.flush
        end
        $log.debug "socket EOF"
      end

      t2 = Thread.start do
        $log.debug "putting to #{url} start"
        start_http(url, :Put) do |http, req|
          req.body_stream = i_pipe
          req["Transfer-Encoding"] = "chunked"
          http.request(req)
        end
        $log.debug "putting to #{url} end"
      end
      [t1, t2]
    end

    def piping_to_socket(url, sock)
      t1 = Thread.start do
        start_http(url, :Get) do |http, req|
          $log.debug "start getting from #{url}"
          http.request req do |response|
            response.read_body do |chunk|
              sock.write chunk
              sock.flush
            end
          end
        end
        $log.debug "getting from #{url} end"
      end
      [t1]
    end
  end
end
