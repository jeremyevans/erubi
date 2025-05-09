require "rake"
require "rake/clean"

NAME = 'erubi'
CLEAN.include ["#{NAME}-*.gem", "rdoc", "coverage"]

# Gem Packaging and Release

desc "Packages #{NAME}"
task :package=>[:clean] do |p|
  sh %{gem build #{NAME}.gemspec}
end

### RDoc

desc "Generate rdoc"
task :rdoc do
  rdoc_dir = "rdoc"
  rdoc_opts = ["--line-numbers", "--inline-source", '--title', 'Erubi: Small ERB Implementation']

  begin
    gem 'hanna'
    rdoc_opts.concat(['-f', 'hanna'])
  rescue Gem::LoadError
  end

  rdoc_opts.concat(['--main', 'README.rdoc', "-o", rdoc_dir] +
    %w"README.rdoc CHANGELOG MIT-LICENSE" +
    Dir["lib/**/*.rb"]
  )

  FileUtils.rm_rf(rdoc_dir)

  require "rdoc"
  RDoc::RDoc.new.document(rdoc_opts)
end

### Specs

spec = proc do |env|
  env.each{|k,v| ENV[k] = v}
  sh "#{FileUtils::RUBY} #{'-w' if RUBY_VERSION >= '3'} #{'-W:strict_unused_block' if RUBY_VERSION >= '3.4'} test/test.rb"
  env.each{|k,v| ENV.delete(k)}
end

desc "Run specs"
task "spec" do
  spec.call({})
end

task :default=>:spec

desc "Run specs with coverage"
task "spec_cov" do
  spec.call('COVERAGE'=>'1')
end

### Other

desc "Start an IRB shell using the extension"
task :irb do
  require 'rbconfig'
  ruby = ENV['RUBY'] || File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name'])
  irb = ENV['IRB'] || File.join(RbConfig::CONFIG['bindir'], File.basename(ruby).sub('ruby', 'irb'))
  sh %{#{irb} -I lib -r #{NAME}}
end


