class TestSpdy < Test::Unit::TestCase
  include TestNetHTTPSPDY

  def test_get_response
    on_headers do |sv, stream_id, headers|
      sr = SPDY::Protocol::Control::SynReply.new({:zlib_session => zlib_session})
      h = {'Content-Type' => 'text/plain', 'status' => '200', 'version' => 'HTTP/1.1'}
      sr.create({:stream_id => stream_id, :headers => h})
      sv.send_data sr.to_binary_s

      d = SPDY::Protocol::Data::Frame.new
      d.create(:stream_id => stream_id, :data => "This is SPDY.", :flags => 1)
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
end
