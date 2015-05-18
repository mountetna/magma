require 'sinatra'
require 'magma-dev-ucsf-immunoprofiler'
require 'yaml'

config = YAML.load(File.read("config.yml"))

Magma.instance.configure config

get '/' do
  "magma-dev"
end

post '/slow' do
  "slow-json-bus - push some data here"
end

post '/fast' do
  "fast-json-api - push some data here"
end
