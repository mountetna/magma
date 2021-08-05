Sequel.migration do
  change do
    create_table(Sequel[:labors][:wounds]) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      foreign_key :victim_id, Sequel[:labors][:victims]
      index :victim_id
      String :location
      Integer :severity
    end
  end
end
