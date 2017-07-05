Sequel.migration do
  change do
    alter_table(:gene_exps) do
      add_column :gene_name, String
    end
  end
end
