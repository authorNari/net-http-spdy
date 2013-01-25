class TestSpdy < Test::Unit::TestCase
  include TestNetHTTPSPDY

  def test_get
    on_headers do |sv, stream_id, headers|
      sr = SPDY::Protocol::Control::SynReply.new(zlib_session: zlib_session)
      h = {'Content-Type' => 'text/plain', 'status' => '200', 'version' => 'HTTP/1.1'}
      sr.create(stream_id: stream_id, headers: h)
      sv.send_data sr.to_binary_s

      d = SPDY::Protocol::Data::Frame.new
      d.create(stream_id: stream_id, data: "This is SPDY.", flags: 1)
      sv.send_data d.to_binary_s

      assert_equal "http", headers['scheme']
      assert_equal "GET", headers['method']
      assert_equal "/", headers['url']
      assert_equal "HTTP/1.1", headers['version']
    end
    start do |http|
      res = http.request_get("/")
      assert_equal '200', res.code
      assert_equal 'This is SPDY.', res.body
    end
  end

  def test_get_without_version
    on_headers do |sv, stream_id, headers|
      sr = SPDY::Protocol::Control::SynReply.new(zlib_session: zlib_session)
      h = {"status" => '200'}
      sr.create(stream_id: stream_id, headers: h, flags: 1)
      sv.send_data sr.to_binary_s
    end
    on_reset do |stream_id, status_code|
      assert_equal 1, status_code
    end
    assert_raise Net::HTTP::SPDY::StreamError do
      start do |http|
        http.request_get("/")
      end
    end
  end

  def test_post
    post_data = ""
    on_headers do |sv, stream_id, headers|
      assert_equal "http", headers['scheme']
      assert_equal "POST", headers['method']
      assert_equal "/", headers['url']
      assert_equal "HTTP/1.1", headers['version']
    end
    on_body do |sv, stream_id, data|
      if data == 'data'
        sr = SPDY::Protocol::Control::SynReply.new(zlib_session: zlib_session)
        h = {'Content-Type' => 'text/plain', 'status' => '200', 'version' => 'HTTP/1.1'}
        sr.create(stream_id: stream_id, headers: h)
        sv.send_data sr.to_binary_s

        d = SPDY::Protocol::Data::Frame.new
        d.create(stream_id: stream_id, data: "OK", flags: 1)
        sv.send_data d.to_binary_s
      end
    end

    start do |http|
      http.request_post("/", 'data') do |res|
        assert_equal '200', res.code
        assert_equal 'OK', res.body
      end
    end
  end
end
