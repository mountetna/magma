require_relative 'lib/magma/server'
require_relative 'lib/magma/parse_body'
require_relative 'lib/magma/auth'
require_relative 'lib/magma/ip_auth'
require_relative 'lib/magma/symbolize_params'
require_relative 'lib/magma'
require 'yaml'
require 'logger'

logger = Logger.new('log/error.log')

use Rack::CommonLogger, logger
use Magma::ParseBody
use Rack::ShowExceptions
use Magma::SymbolizeParams
use Magma::Auth, YAML.load(File.read('config.yml')))

run Magma::Server.new(YAML.load(File.read('config.yml')), logger)
