Sequel.migration do
  change do
    alter_table(:patients) do
      add_column :gross_specimen, String
      add_column :notes, String
    end
  end
end
