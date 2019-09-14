module Labors
  class Labor < Magma::Model
    parent :project

    identifier :name, type: String

    child :monster

    attribute :number, type: Integer
    attribute :completed, type: TrueClass
    attribute :year, type: DateTime

    table :prize

    matrix :contributions, match: [ 'Athens', 'Sparta', 'Sidon', 'Thebes' ]
  end
end
