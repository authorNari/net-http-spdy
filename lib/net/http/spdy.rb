# -*- coding: utf-8 -*-
require 'net/http'
$: << File.join(File.dirname(__FILE__), "../../../vender/spdy/lib/")
require 'spdy'
require 'openssl'

# A SPDY HTTP Client with Net::HTTP
#
# Net::HTTP::SPDY has created with extending Net::HTTP.
# See Net::HTTP, if you want to know major usages.
# 
# Different points from Net::HTTP to Net::HTTP::SPDY are here.
#
# == A TCP socket per multi-streams
# 
# A TCP Socket conneted with Net::HTTP::SPDY will not close usually
# until you call Net::HTTP#finish.
# And, you can use multi-thread to send HTTP requests continuously.
#
# Example:
#
#   require 'net/http/spdy'
#   
#   flag_uris = %w(
#      images_sm/ad_flag.png images_sm/ae_flag.png
#      images_sm/af_flag.png images_sm/ag_flag.png
#      images_sm/ai_flag.png images_sm/am_flag.png
#      images_sm/ao_flag.png images_sm/ar_flag.png
#      images_sm/as_flag.png images_sm/at_flag.png).map do |path|
#     URI('https://www.modspdy.com/world-flags/' + path)
#   end
#   fetch_threads = []
#   uri = URI('https://www.modspdy.com/world-flags/')
#   Net::HTTP::SPDY.start(uri.host, uri.port, use_ssl: true) do |http|
#     flag_uris.each do |uri|
#       req = Net::HTTP::Get.new(uri)
#       fetch_threads << Thread.start do
#         http.request(req)
#       end
#     end
#     fetch_threads.each(&:join)
#   end
#
# == Server push
#
# You can check to exist HTTP responses pushed by a server by
# Net::HTTPResponse#has_associatd_response? and you can take
# it by Net::HTTPResponse#associated_responses .
#
class Net::HTTP::SPDY < Net::HTTP
  def initialize(address, port = nil)
    super
    @npn_select_cb = ->(protocols) do
      prot = protocols.detect{|pr| pr == "spdy/2"}
      if prot.nil?
        raise "This server doesn't support SPDYv2"
      end
      prot
    end
  end

  if RUBY_VERSION >= "2.0.0"
    SSL_IVNAMES << :@npn_select_cb
    SSL_ATTRIBUTES << :npn_select_cb
  end

  undef :close_on_empty_response= if defined?(self.close_on_empty_response=true)

  private

  def connect
    if RUBY_VERSION < "2.0.0" && use_ssl?
      raise ArgumentError, "Supports SSL in Ruby 2.0.0 or later only"
    end
    super
    @stream_session = StreamSession.new(@socket)
  end

  def transport_request(req)
    begin_transport req
    req.uri = URI((use_ssl? ? "https://" : "http://") + addr_port + req.path)
    stream = @stream_session.create(req.uri)
    res = nil
    res = catch(:response) {
      req.exec stream, @curr_http_version, edit_path(req.path)
      begin
        r = Net::HTTPResponse.read_new(stream)
      end while res.kind_of?(Net::HTTPContinue)

      r.uri = req.uri

      r.reading_body(stream, req.response_body_permitted?) {
        yield r if block_given?
      }
      r
    }
    stream.assocs.each do |s|
      if not s.eof?
        begin
          r = Net::HTTPResponse.read_new(s)
        end while r.kind_of?(Net::HTTPContinue)
        r.reading_body(s, true) {
          yield r if block_given?
        }
        r.uri = s.uri
        res.associated_responses << r
      end
    end

    end_transport req, res
    res
  rescue => exception
    D "Conn close because of error #{exception}"
    @socket.close if @socket and not @socket.closed?
    raise exception
  end

  def end_transport(req, res)
    # nothing to do
  end

  def sspi_auth?(res)
    return false
  end

  def keep_alive?(req, res)
    return false
  end

  def proxy?
    # TODO: supports proxy
    return false
  end
end

require 'net/http/spdy/stream'
require 'net/http/spdy/stream_session'
require 'net/http/spdy/generic_request'
require 'net/http/spdy/response'
