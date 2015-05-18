Sequel.migration do
  change do
    alter_table(:gene_exps) do
      add_column :created_at, DateTime
      add_column :updated_at, DateTime
    end
    alter_table(:experiments) do
      add_column :created_at, DateTime
      add_column :updated_at, DateTime
    end
    alter_table(:projects) do
      add_column :created_at, DateTime
      add_column :updated_at, DateTime
    end
    alter_table(:dc_stains) do
      add_column :created_at, DateTime
      add_column :updated_at, DateTime
    end
    alter_table(:patients) do
      add_column :created_at, DateTime
      add_column :updated_at, DateTime
    end
    alter_table(:samples) do
      add_column :created_at, DateTime
      add_column :updated_at, DateTime
    end
    alter_table(:rna_seqs) do
      add_column :created_at, DateTime
      add_column :updated_at, DateTime
    end
    alter_table(:rna_seq_batches) do
      add_column :created_at, DateTime
      add_column :updated_at, DateTime
    end
    alter_table(:treg_stains) do
      add_column :created_at, DateTime
      add_column :updated_at, DateTime
    end
    alter_table(:nktb_stains) do
      add_column :created_at, DateTime
      add_column :updated_at, DateTime
    end
    alter_table(:sort_stains) do
      add_column :created_at, DateTime
      add_column :updated_at, DateTime
    end
    alter_table(:rna_seq_qcs) do
      add_column :created_at, DateTime
      add_column :updated_at, DateTime
    end
  end
end
