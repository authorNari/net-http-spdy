require 'forwardable'

class Net::HTTP::SPDY::Stream
  extend Forwardable

  attr_accessor :buf, :eof, :connected
  attr_reader :sock, :uri, :assocs, :new_assoc, :id
  def_delegators :@sock, :io, :closed?, :close

  def initialize(id, session, sock, uri)
    @id = id
    @session = session
    @sock = sock
    @buf = ""
    @eof = false
    @uri = uri
    @assocs = []
    @new_assoc = nil
    @connected = false
  end

  def eof?
    @buf.empty? && (@eof || @sock.eof?)
  end

  def read(len, dest = '', ignore_eof = false)
    while @buf.size < len
      read_frame(ignore_eof)
      break if ignore_eof && eof?
    end
    dest << rbuf_consume(len)
    return dest
  end

  def read_all(dest = '')
    dest << rbuf_consume(@buf.size)
    until eof?
      read_frame(false)
      dest << rbuf_consume(@buf.size)
    end
    return dest
  end

  def readuntil(terminator, ignore_eof = false)
    idx = @buf.index(terminator)
    while idx.nil?
      read_frame(ignore_eof)
      idx = @buf.index(terminator)
      idx = @buf.size if ignore_eof && eof?
    end
    return rbuf_consume(idx + terminator.size)
  end

  def readline
    readuntil("\n").chop
  end

  def write(buf)
    d = SPDY::Protocol::Data::Frame.new
    d.create(stream_id: @id, data: buf)
    @session.monitor.synchronize do
      @sock.write d.to_binary_s
    end
  end
  alias << write

  def write_headers(method, path, ver, request)
    h = {
      'method' => method,
      'url' => path,
      'version' => "HTTP/#{ver}",
      'scheme' => request.uri.scheme
    }
    h['host'] = request.delete("host").first

    %w(Connection Host Keep-Alive Proxy-Connection Transfer-Encoding).each do |i|
      raise ArgumentError, "Can't send #{i} with SPDY" if not request[i].nil?
    end

    sr = SPDY::Protocol::Control::SynStream.new(zlib_session: @session.parser.zlib_session)
    request.each_header do |key, value|
      h[key.downcase] = value
    end
    if request.request_body_permitted?
      sr.create(stream_id: @id, headers: h)
    else
      sr.create(stream_id: @id, headers: h, flags: 1)
    end
    @sock.debug_output.puts h if @sock.debug_output
    @session.monitor.synchronize do
      # wait to open a lower stream
      @session.monitor_cond.wait_while do
        @session.streams.detect{|s| s.id < @id && !s.connected }
      end
      @sock.write sr.to_binary_s
      @connected = true
      @session.monitor_cond.broadcast
    end
  end

  def close_write
    d = SPDY::Protocol::Data::Frame.new
    d.create(stream_id: @id, flags: 1)
    @session.monitor.synchronize do
      @sock.write d.to_binary_s
    end
  end

  private

  BUFSIZE = 1024 * 16
  def read_frame(ignore_eof)
    while buf.empty?
      raise EOFError if eof? && !ignore_eof
      @session.monitor.synchronize do
        begin
          return if not buf.empty?
          s = @sock.io.read_nonblock(BUFSIZE)
          @session.parse(s)
        rescue IO::WaitReadable
          if IO.select([@sock.io], nil, nil, @sock.read_timeout)
            retry
          else
            raise Net::ReadTimeout
          end
        rescue IO::WaitWritable
          if IO.select(nil, [@sock.io], nil, @sock.read_timeout)
            retry
          else
            raise Net::ReadTimeout
          end
        end
      end
    end
  rescue EOFError
    raise unless ignore_eof
  end

  def rbuf_consume(len)
    @buf.slice!(0, len)
  end
end
