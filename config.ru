require 'yaml'
require 'bundler'
Bundler.require(:default)

require_relative 'lib/magma/server'
require_relative 'lib/magma/auth'
require_relative 'lib/magma'

use Etna::ParseBody
use Etna::SymbolizeParams
use Magma::Auth

run Magma::Server.new(YAML.load(File.read('config.yml')))
