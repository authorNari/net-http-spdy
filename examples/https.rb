require 'net/http/persistent'

flag_uris = %w(
   images_sm/ad_flag.png images_sm/ae_flag.png
   images_sm/af_flag.png images_sm/ag_flag.png
   images_sm/ai_flag.png images_sm/am_flag.png
   images_sm/ao_flag.png images_sm/ar_flag.png
   images_sm/as_flag.png images_sm/at_flag.png).map do |path|
  URI('https://www.modspdy.com/world-flags/' + path)
end
uri = URI('https://www.modspdy.com/')
http = Net::HTTP::Persistent.new
flag_uris.each do |uri|
  http.request(uri)
end
