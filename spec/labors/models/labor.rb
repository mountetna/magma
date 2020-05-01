module Labors
  class Labor < Magma::Model
    parent :project

    identifier :name

    child :monster

    integer :number
    boolean :completed
    date_time :year

    table :prize

    matrix :contributions, match: [ 'Athens', 'Sparta', 'Sidon', 'Thebes' ]
  end
end
