Sequel.migration do
  change do
    create_table(:projects) do
      primary_key :id
      String :name
      unique :name
    end
    create_table(:experiments) do
      primary_key :id
      foreign_key :project_id, :projects
      String :name
      unique :name
      String :description
    end
    alter_table(:sort_stains) do
      add_foreign_key :sample_id, :samples
    end
    alter_table(:samples) do
      add_foreign_key :patient_id, :patients
      add_foreign_key :experiment_id, :experiments
    end
    alter_table(:dc_stains) do
      add_foreign_key :sample_id, :samples
    end
    alter_table(:gene_exps) do
      add_foreign_key :rna_seq_id, :rna_seqs
    end
    alter_table(:nktb_stains) do
      add_foreign_key :sample_id, :samples
    end
    alter_table(:rna_seqs) do
      add_foreign_key :sample_id, :samples
      add_foreign_key :rna_seq_batch_id, :rna_seq_batches
    end
  end
end
