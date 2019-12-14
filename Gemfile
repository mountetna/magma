source 'http://rubygems.org'

ruby '2.5.7'

gem 'etna'
gem 'pg'
gem 'sequel'
gem 'mini_magick'
gem 'fog-aws'
gem 'carrierwave-sequel'
gem 'carrierwave'
gem 'activesupport', '>= 4.2.6'
gem 'spreadsheet'

group :test do
  gem 'simplecov'
  gem 'rack-test', require: "rack/test"
  gem 'factory_bot'
  gem 'webmock'
  gem 'rspec'
  gem 'database_cleaner'
  gem 'pry'
  gem 'timecop'
  gem 'net-http-persistent'
  gem 'multipart-post'
end

Dir.glob File.expand_path("projects/*/Gemfile",__dir__) do |file|
  instance_eval File.read(file)
end
