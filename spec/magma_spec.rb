require_relative '../lib/magma'
require 'yaml'

db_config = YAML.load File.read("../../config.yml")
Magma.instance.connect db_config[:database]

describe Magma do
  describe ".connect" do
    it "creates a Sequel database connection" do
    end
  end

  describe ".configure" do
    it "loads models and validates tables" do
    end
  end

  describe ".get_model" do
    it "returns the class for a given model name" do
    end
  end
  describe ".magma_models" do
    it "returns a list of all magma models" do
    end
  end
end
