class Victim < Magma::Model
  parent :monster

  attribute :name, type: String
  attribute :manner_of_death, type: String,
    match: [ "eaten", "poisoned", "crushed", "mangled" ]
end
