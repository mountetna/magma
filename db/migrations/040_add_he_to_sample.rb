Sequel.migration do
  change do
    alter_table(:samples) do
      add_column :he_stain, String
    end
  end
end
