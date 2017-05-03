Sequel.migration do
  change do
    alter_table(:rna_seq_plates) do
      add_foreign_key :project_id, :projects
      add_index :project_id
    end
  end
end
