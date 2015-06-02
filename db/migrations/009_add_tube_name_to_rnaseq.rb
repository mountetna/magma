Sequel.migration do
  change do
    alter_table(:rna_seqs) do
      add_column :tube_name, String
      add_unique_constraint :tube_name
    end
  end
end
