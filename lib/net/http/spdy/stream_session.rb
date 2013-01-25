# -*- coding: utf-8 -*-
require 'monitor'

class Net::HTTP::SPDY
  class StreamError < StandardError; end

  class StreamSession
    attr_reader :parser, :monitor, :monitor_cond

    def initialize(sock)
      @sock = sock
      @highest_id = -1
      @streams = {}
      @parser = create_parser
      @monitor = Monitor.new
      @monitor_cond = @monitor.new_cond
    end
  
    def create(uri)
      @monitor.synchronize do
        @highest_id += 2
      end
      return push(@highest_id, uri)
    end
  
    def known?(id)
      @streams.has_key?(id)
    end
  
    def push(id, uri, connected=false)
      s = Stream.new(id, self, @sock, uri)
      s.connected = connected
      @streams[id] = s
      return @streams[id]
    end
  
    def parse(buf)
      @parser << buf
    end
  
    def streams
      @streams.values
    end
  
    private
  
    def create_parser
      parser = SPDY::Parser.new
      parser.on_open do |id, assoc_id, pri|
        @sock.debug_output.puts "on_open: id=<#{id}>,assoc_id=<#{assoc_id}>" if @sock.debug_output
        if assoc_id
          s = @streams.fetch(id)
          s.new_assoc = assoc_id
        end
      end
      parser.on_headers do |id, headers|
        @sock.debug_output.puts "on_headers: id=<#{id}>, headers=<#{headers}>" if @sock.debug_output
        s = @streams.fetch(id)
        if s.new_assoc
          # TODO: check invalid header and send PROTOCOL_ERROR
          uri = URI(headers.delete('url'))
          assoc = push(s.new_assoc, uri, true)
          s.new_assoc = nil
          s.assocs << assoc
          s = assoc
        else
          s = @streams.fetch(id)
        end
  
        h = ["#{headers['version']} #{headers['status']}"]
        if headers['version'].nil? or headers['status'].nil?
          s.write_protocol_error
          raise StreamError, "Receives a SYN_REPLY without a status or without a version header"
        end
        code, msg = headers.delete('status').split(" ")
        r = ::Net::HTTPResponse.new(headers.delete('version'), code, msg)
        r.each_capitalized{|k,v| h << "#{k}: #{v}" }
        h << "\r\n"
  
        @sock.debug_output.puts %Q[->#{h.join("\r\n").dump}] if @sock.debug_output
        s.buf << h.join("\r\n")
      end
      parser.on_body do |id, data|
        @sock.debug_output.puts "on_body: id=<#{id}>" if @sock.debug_output
        s = @streams.fetch(id)
        @sock.debug_output.puts %Q[->#{data.dump}] if @sock.debug_output
        s.buf << data
      end
      parser.on_message_complete do |id|
        @sock.debug_output.puts "on_message_complete: id=<#{id}>" if @sock.debug_output
        # TODO: send frame to close
        @streams.fetch(id).eof = true
        @streams.delete(id)
      end
      parser.on_reset do |id, status|
        @sock.debug_output.puts "on_reset: id=<#{id}>, status=<#{status}>" if @sock.debug_output
        case status
        when 1
          raise StreamError, 'received PROTOCOL_ERROR'
        when 2
          raise StreamError, 'received INVALID_STREAM'
        when 3
          raise StreamError, 'received REFUSED_STREAM'
        when 4
          raise StreamError, 'received UNSUPPORTED_VERSION'
        when 5
          raise StreamError, 'received CANCEL'
        when 6
          raise StreamError, 'received INTERNAL_ERROR'
        when 7
          raise StreamError, 'received FLOW_CONTROL_ERROR'
        end
      end
      return parser
    end
  end
end
