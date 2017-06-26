Sequel.migration do
  change do
    create_table(:rna_seqs) do
      primary_key :id
      String :compartment
      Integer :cell_number
      Float :mass
      String :expression_type
    end
    alter_table(:patients) do
      add_column :ipi_number, String
      add_unique_constraint :ipi_number
    end
    create_table(:dc_stains) do
      primary_key :id
      String :tube_name
      unique :tube_name
      Integer :total_stained_count
      Integer :total_acquired_count
      Integer :live_count
      Integer :cd45_count
      Integer :t_count
      Integer :neutrophil_count
      Integer :monocyte_count
      Integer :peripheral_dc_count
      Integer :dc1_count
      Integer :dc2_count
      Integer :cd14_pos_tam_count
      Integer :cd14_neg_tam_count
    end
    create_table(:flow_datum) do
      primary_key :id
    end
    create_table(:gene_exps) do
      primary_key :id
      Float :read_counts
      Float :expression
    end
    create_table(:nktb_stains) do
      primary_key :id
      String :tube_name
      unique :tube_name
      Integer :total_stained_count
      Integer :total_acquired_count
      Integer :live_count
      Integer :cd45_count
      Integer :t_count
      Integer :nk_count
      Integer :b_count
    end
    create_table(:rna_seq_batches) do
      primary_key :id
      String :batch_name
      unique :batch_name
      DateTime :run_date
    end
    create_table(:rna_seq_qcs) do
      primary_key :id
      Integer :total_reads
      Float :rRNA_reads
      Float :intergenic_reads
      Float :coding_reads
      Float :intronic_reads
      Float :utr_reads
    end
    create_table(:samples) do
      primary_key :id
      String :sample_name
      unique :sample_name
      String :tumor_type
      Float :weight
      String :site
      String :stage
      String :grade
      String :physician
      DateTime :ice_time
      String :description
      DateTime :date_of_flow
      DateTime :date_of_digest
      DateTime :date_of_extraction
      Integer :post_digest_cell_count
    end
    create_table(:sort_stains) do
      primary_key :id
      String :tube_name
      unique :tube_name
      Integer :total_stained_count
      Integer :total_acquired_count
      Integer :live_count
      Integer :cd45_count
      Integer :lineage_neg_count
      Integer :stroma_count
      Integer :myeloid_count
      Integer :t_count
      Integer :tumor_count
    end
    create_table(:treg_stains) do
      primary_key :id
      String :tube_name
      unique :tube_name
      Integer :total_stained_count
      Integer :total_acquired_count
      Integer :live_count
      Integer :treg_count
      Integer :teff_count
    end
  end
end
