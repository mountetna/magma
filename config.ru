require_relative 'gem/lib/magma/server'
require_relative 'gem/lib/magma'
require 'yaml'

use Magma::Auth
use Magma::JsonBody

run Magma::Server.new(YAML.load File.read("config.yml"))
