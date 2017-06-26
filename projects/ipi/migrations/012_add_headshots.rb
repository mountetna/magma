Sequel.migration do
  change do
    alter_table(:samples) do
      add_column :headshot, String
    end
  end
end
