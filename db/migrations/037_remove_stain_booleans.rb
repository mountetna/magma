Sequel.migration do
  change do
    alter_table(:samples) do
      drop_column :treg_stain
      drop_column :nktb_stain
      drop_column :sort_stain
      drop_column :dc_stain
    end
  end
end
