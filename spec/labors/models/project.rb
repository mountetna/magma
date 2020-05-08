module Labors
  class Project < Magma::Model
    identifier :name, description: 'Name for this project'

    collection :labor

    # data dictionary for monster aspects
    table :codex
  end
end
