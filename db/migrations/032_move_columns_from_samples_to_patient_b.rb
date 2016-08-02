Sequel.migration do
  change do
    alter_table(:samples) do
      drop_column :ice_time
      drop_column :physician
      drop_column :date_of_digest
      drop_column :date_of_extraction
    end
  end
end
