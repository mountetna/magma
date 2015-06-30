Sequel.migration do
  change do
    alter_table(:patients) do
      String :gross_specimen
      String :notes
    end
  end
end
