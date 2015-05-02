$: << "../lib"

require 'magma'
require 'yaml'

db_config = YAML.load File.read("../../database.yml")
Magma.instance.connect db_config

describe Magma::Model do
  describe ".identifier" do
    class Patient < Magma::Model
    end
  end
end
