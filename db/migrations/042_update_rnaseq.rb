Sequel.migration do
  change do
    alter_table(:gene_exps) do
      rename_column :gene_name, :ensembl_name
      add_index :ensembl_name
      add_column :hugo_name, String
      add_index :hugo_name
    end
    create_table(:fastqs) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      foreign_key :rna_seq_id, :rna_seqs
      String :read1
      String :read2
    end
    create_table(:rna_seq_plates) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      String :plate_name
      unique :plate_name
      DateTime :submission_date
      String :library_prep
    end
    alter_table(:rna_seqs) do
      add_foreign_key :rna_seq_plate_id, :rna_seq_plates
      add_column :bam_file, String
      add_column :bam_index, String
      add_column :transcriptome_build, String
      add_column :read_count, Integer
      add_column :duplicate_count, Integer
      add_column :mapped_count, Integer
      add_column :intergenic_count, Integer
      add_column :introns_count, Integer
      add_column :utr_count, Integer
      add_column :coding_count, Integer
      add_column :mt_coding_count, Integer
      add_column :rrna_count, Integer
      add_column :mt_rrna_count, Integer
      add_column :median_3prime_bias, Float
      add_column :median_cv_coverage, Float
      add_column :eisenberg_score, Integer
      drop_column :mass
    end
  end
end
