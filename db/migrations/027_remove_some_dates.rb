Sequel.migration do
  change do
    alter_table(:samples) do
      drop_column :date_of_flow
      drop_column :date_of_fixation
      drop_column :fixation_time
    end
  end
end
