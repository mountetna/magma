require 'sinatra'
require 'magma-dev-ucsf-immunoprofiler'
require 'yaml'

db_config = YAML.load(File.read("database.yml"))

magma = Magma.instance
# connect to the magma instance
magma.connect(db_config)

# validate your models
magma.validate_models

get '/' do
  "magma-dev"
end

post '/slow' do
  "slow-json-bus - push some data here"
end

post '/fast' do
  "fast-json-api - push some data here"
end


