# frozen_string_literal: true
require File.expand_path("../lib/erubi", __FILE__)

Gem::Specification.new do |s|
  s.name = 'erubi'
  s.version = Erubi::VERSION
  s.platform = Gem::Platform::RUBY
  s.extra_rdoc_files = ["README.rdoc", "CHANGELOG", "MIT-LICENSE"]
  s.rdoc_options += ["--quiet", "--line-numbers", "--inline-source", '--title', 'Erubi: Small ERB Implementation', '--main', 'README.rdoc']
  s.license = "MIT"
  s.summary = "Small ERB Implementation"
  s.author = ["Jeremy Evans", 'kuwata-lab.com']
  s.email = "code@jeremyevans.net"
  s.homepage = "https://github.com/jeremyevans/erubi"
  s.files = %w(MIT-LICENSE CHANGELOG README.rdoc Rakefile lib/erubi.rb lib/erubi/capture_end.rb)
  s.description = "Erubi is a ERB template engine for ruby. It is a simplified fork of Erubis"
  s.add_development_dependency "minitest"
  s.add_development_dependency "minitest-global_expectations"
  s.metadata = {
    'bug_tracker_uri'   => 'https://github.com/jeremyevans/erubi/issues',
    'changelog_uri'     => 'https://github.com/jeremyevans/erubi/blob/master/CHANGELOG',
    'source_code_uri'   => 'https://github.com/jeremyevans/erubi',
  }
end
