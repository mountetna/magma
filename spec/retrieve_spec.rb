require_relative '../lib/magma/server/retrieve'

# This helper manages the retrieval of a bunch of records.
# It returns a Payload
#
# Let's say we have a model like this:
# Dogs {
#   identifier :name
#   attribute :breed
#   table :tricks
# }
# 
# joined to:
# Trick {
#   identifier :name
#   attribute :skill_level
# }
#
#

describe Magma::Server::Retrieve do
  describe "#initialize" do
    it "complains without inputs" do
      expect {
        Magma::Server::Retrieve.new()
      }.to raise_error(ArgumentError)
    end
  end

  describe "#to_json" do
    it "returns a json version of the records" do
    end
  end
end
