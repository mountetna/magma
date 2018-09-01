module Labors
  class Codex < Magma::Model
    parent :project

    attribute :monster, type: String
    attribute :aspect, type: String
    attribute :tome, type: String
    attribute :lore, type: :json
  end
end
