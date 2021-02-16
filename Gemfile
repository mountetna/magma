source 'http://rubygems.org'

# HACK to maybe fix stupid rubygems bug
require 'fileutils'

ruby '~> 2.5'

gem 'etna', git: 'https://github.com/mountetna/monoetna.git', branch: 'refs/artifacts/gem-etna/9e9d2746302e2e029a79d76870b04cf50aa876eb'
gem 'pg'
gem 'sequel', '5.28.0'
gem 'mini_magick'
gem 'carrierwave-sequel'
gem 'carrierwave'
gem 'activesupport', '>= 4.2.6'
gem 'spreadsheet'
gem 'puma', '5.0.2'
gem 'nokogiri'
gem 'curb' # used by ipi project.

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
