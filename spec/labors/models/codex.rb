module Labors
  class Codex < Magma::Model
    parent :project

    attribute :aspect, type: String
    attribute :tome, type: String
    attribute :values, type: :json
  end
end
