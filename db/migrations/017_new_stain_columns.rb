Sequel.migration do
  change do
    alter_table(:nktb_stains) do
      add_column :cd4_count, Integer
      add_column :cd8_count, Integer
      add_column :hladr_count, Integer
      add_column :hladr_cd3e_neg_count, Integer
    end
    alter_table(:sort_stains) do
      add_column :lineage_count, Integer
    end
    alter_table(:treg_stains) do
      add_column :t_count, Integer
      add_column :hladr_count, Integer
      add_column :cd4_count, Integer
      add_column :cd45_count, Integer
      add_column :cd8_count, Integer
      add_column :cd3_neg_count, Integer
    end
  end
end
