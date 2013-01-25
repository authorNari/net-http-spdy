if RUBY_VERSION >= "2.0.0"
  class TestAccessToWeb < Test::Unit::TestCase
    def test_get_google
      uri = URI('https://www.google.com/')
      http = Net::HTTP::SPDY.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.start do |http|
        req = Net::HTTP::Get.new(uri)
        res = http.request(req)
        assert_include ["200", "302"], res.code
      end
    end
  
    def test_get_google_simple
      uri = URI('https://www.google.com/')
      Net::HTTP::SPDY.start(uri.host, uri.port, use_ssl: true) do |http|
        res = http.get("/")
        assert_include ["200", "302"], res.code
      end
    end
  
    def test_get_world_flags_parallel
      flag_uris = %w(
         images_sm/ad_flag.png images_sm/ae_flag.png
         images_sm/af_flag.png images_sm/ag_flag.png
         images_sm/ai_flag.png images_sm/am_flag.png
         images_sm/ao_flag.png images_sm/ar_flag.png
         images_sm/as_flag.png images_sm/at_flag.png).map do |path|
        URI('https://www.modspdy.com/world-flags/' + path)
      end
      fetch_threads = []
      uri = URI('https://www.modspdy.com/world-flags/')
      http = Net::HTTP::SPDY.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      #http.set_debug_output $stderr
      http.start
      flag_uris.each do |uri|
        req = Net::HTTP::Get.new(uri)
        #fetch_threads << Thread.start do
          res = http.request(req)
          assert_equal "200", res.code
        #end
      end
      fetch_threads.each(&:join)
      http.finish
    end
  end
end
