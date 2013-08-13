# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "siriproxy-vera"
  s.version     = "0.0.1" 
  s.authors     = ["andrewgarfield"]
  s.email       = [""]
  s.homepage    = ""
  s.summary     = %q{A SiriProxy plugin to run scenes on your VeraLite}
  s.description = %q{This plugin will set scenes on your VeraLite. }

  s.rubyforge_project = "siriproxy-example"

  s.files         = `git ls-files 2> /dev/null`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/* 2> /dev/null`.split("\n")
  s.executables   = `git ls-files -- bin/* 2> /dev/null`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  # s.add_runtime_dependency "rest-client"
  s.add_runtime_dependency "httpclient"
  s.add_runtime_dependency "multi_json"
end
