# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "net/http/spdy/version"

Gem::Specification.new do |s|
  s.name        = "net-http-spdy"
  s.version     = Net::HTTP::SPDY::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Narihiro Nakamura"]
  s.email       = ["authornari@gmail.com"]
  s.homepage    = "https://github.com/authorNari/spdy"
  s.summary     = "A SPDY HTTP client implementation atop Net:HTTP"
  s.description = s.summary

  s.files         = `git ls-files`.split($\)
  s.executables   = s.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.name          = "net-http-spdy"
  s.require_paths = ["lib"]

  s.add_dependency "bindata"
  s.add_dependency "ffi-zlib"
end