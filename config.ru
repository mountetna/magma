require 'yaml'
require 'bundler'
Bundler.require(:default)

require_relative 'lib/magma/server'
require_relative 'lib/magma'

Magma.instance.configure(YAML.load(File.read('config.yml')))
use Etna::CrossOrigin
use Etna::MetricsExporter
use Etna::ParseBody
use Etna::SymbolizeParams
use Etna::Auth
use Etna::DescribeRoutes
run Magma::Server.new
