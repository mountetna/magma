require 'yaml'
require 'bundler'
Bundler.require(:default)

require_relative 'lib/magma/server'
require_relative 'lib/magma'

Magma.instance.configure(YAML.load(File.read('config.yml')))
use Etna::CrossOrigin
use Etna::ParseBody
use Etna::SymbolizeParams
use Etna::Auth
run Magma::Server.new
