Sequel.migration do
  change do
    alter_table(:samples) do
      add_column :he_low, String
      add_column :he_high, String
      add_column :he_zstack, String
      drop_column :he_stain
    end
  end
end
