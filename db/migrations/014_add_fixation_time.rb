Sequel.migration do
  change do
    alter_table(:samples) do
      add_column :date_of_fixation, DateTime
      add_column :fixation_time, DateTime
    end
  end
end
