class Net::HTTPGenericRequest
  attr_writer :uri

  alias exec_wo_spdy exec
  def exec(sock, ver, path)   #:nodoc: internal use only
    exec_wo_spdy(sock, ver, path)
    if is_spdy?(sock) && (@body || @body_stream || @body_data)
      sock.close_write
    end
  end

  private
  alias send_request_with_body_stream_wo_spdy send_request_with_body_stream
  def send_request_with_body_stream(sock, ver, path, f)
    if is_spdy?(sock)
      stream = sock
      write_header stream, ver, path
      wait_for_continue stream, ver if stream.continue_timeout
      IO.copy_stream(f, stream)
    else
      send_request_with_body_stream_wo_spdy
    end
  end

  alias write_header_wo_spdy write_header
  def write_header(sock, ver, path)
    if is_spdy?(sock)
      stream = sock
      stream.write_headers(@method, path, ver, self)
    else
      write_header_wo_spdy(sock, ver, path)
    end
  end

  def is_spdy?(sock)
    sock.kind_of?(Net::HTTP::SPDY::Stream)
  end
end
