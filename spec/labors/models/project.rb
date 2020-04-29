module Labors
  class Project < Magma::Model
    identifier :name, type: String, description: 'Name for this project'

    collection :labor

    # data dictionary for monster aspects
    table :codex
  end
end
