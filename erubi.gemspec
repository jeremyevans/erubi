Gem::Specification.new do |s|
  s.name = 'erubi'
  s.version = '1.5.0'
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ["README.rdoc", "CHANGELOG", "MIT-LICENSE"]
  s.rdoc_options += ["--quiet", "--line-numbers", "--inline-source", '--title', 'Erubi: Small ERB Implementation', '--main', 'README.rdoc']
  s.license = "MIT"
  s.summary = "Small ERB Implementation"
  s.author = ["Jeremy Evans", 'kuwata-lab.com']
  s.email = "code@jeremyevans.net"
  s.homepage = "https://github.com/jeremyevans/erubi"
  s.files = %w(MIT-LICENSE CHANGELOG README.rdoc Rakefile) + Dir["{test,lib}/**/*.rb"]
  s.description = "Erubi is a ERB template engine for ruby. It is a simplified fork of Erubis"
  s.add_development_dependency "minitest"
  s.add_development_dependency "benchmark-ips"
end
