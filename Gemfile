source 'http://rubygems.org'

ruby '~> 2.5'

gem 'etna', git: 'https://github.com/mountetna/monoetna.git', branch: 'refs/artifacts/gem-etna/842e38390a391118f0f6e0bfc27bc5d4ebb1ac7b'
gem 'pg'
gem 'sequel', '5.28.0'
gem 'mini_magick'
gem 'fog-aws'
gem 'carrierwave-sequel'
gem 'carrierwave'
gem 'activesupport', '>= 4.2.6'
gem 'spreadsheet'
gem 'puma', '5.0.2'

group :test do
  gem 'simplecov'
  gem 'rack-test', require: "rack/test"
  gem 'factory_bot'
  gem 'webmock'
  gem 'rspec'
  gem 'database_cleaner'
  gem 'pry'
  gem 'pry-byebug'
  gem 'timecop'
  gem 'net-http-persistent'
  gem 'multipart-post'
  gem 'debase'
  gem 'ruby-debug-ide'
end

Dir.glob File.expand_path("projects/*/Gemfile",__dir__) do |file|
  instance_eval File.read(file)
end
