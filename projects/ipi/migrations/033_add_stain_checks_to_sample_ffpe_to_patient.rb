Sequel.migration do
  change do
    alter_table(:patients) do
      add_column :ffpe_frozen, TrueClass
    end
    alter_table(:samples) do
      add_column :treg_stain, TrueClass
      add_column :nktb_stain, TrueClass
      add_column :sort_stain, TrueClass
      add_column :dc_stain, TrueClass
    end
  end
end
