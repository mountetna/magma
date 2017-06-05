Sequel.migration do
  change do
    alter_table(:samples) do
      add_column :innate_file, String
    end
  end
end
