require_relative 'lib/magma/server'
require_relative 'lib/magma'
require 'yaml'
require 'logger'

logger = Logger.new('log/error.log')

use Rack::CommonLogger, logger
use Magma::IpAuth
use Magma::ParseBody
use Rack::ShowExceptions

run Magma::Server.new(YAML.load File.read('config.yml'))
