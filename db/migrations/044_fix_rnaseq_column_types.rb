Sequel.migration do
  change do
    alter_table(:rna_seqs) do
      set_column_type :intergenic_count, Float
      set_column_type :introns_count, Float
      set_column_type :utr_count, Float
      set_column_type :coding_count, Float
      set_column_type :mt_coding_count, Float
      set_column_type :rrna_count, Float
      set_column_type :mt_rrna_count, Float
    end
  end
end
