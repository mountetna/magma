source 'http://rubygems.org'

# HACK to maybe fix stupid rubygems bug
require 'fileutils'

ruby '~> 2.5'

gem 'etna', git: 'https://github.com/mountetna/monoetna.git', branch: 'refs/artifacts/gem-etna/4fb09d6bc1119282082c64eb5b490a782c079b7f'
gem 'pg'
gem 'sequel', '5.28.0'
gem 'mini_magick'
gem 'activerecord'
gem 'activesupport', '>= 4.2.6'
gem 'spreadsheet'
gem 'puma', '5.0.2'
gem 'curb' # used by ipi project.
gem 'concurrent-ruby'

group :test do
  gem 'simplecov'
  gem 'rack-test', require: "rack/test"
  gem 'factory_bot'
  gem 'webmock'
  gem 'rspec'
  gem 'database_cleaner', '1.8.0'
  gem 'pry'
  gem 'pry-byebug'
  gem 'timecop'
  gem 'net-http-persistent'
  gem 'multipart-post'
  gem 'debase'
end

Dir.glob File.expand_path("projects/*/Gemfile",__dir__) do |file|
  instance_eval File.read(file)
end
