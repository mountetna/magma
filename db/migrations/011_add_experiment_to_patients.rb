Sequel.migration do
  change do
    alter_table(:patients) do
      add_foreign_key :experiment_id, :experiments
    end
  end
end
