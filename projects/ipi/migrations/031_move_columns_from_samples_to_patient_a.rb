Sequel.migration do
  change do
    alter_table(:patients) do
      add_column :ice_time, Float
      add_column :physician, String
      add_column :date_of_digest, DateTime
      add_column :date_of_extraction, DateTime
    end
  end
end
