require 'net/http/spdy'

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
http.start
flag_uris.each do |uri|
  req = Net::HTTP::Get.new(uri)
  fetch_threads << Thread.start do
    http.request(req)
  end
end
fetch_threads.each(&:join)
http.finish
