Sequel.migration do
  change do
    alter_table(:treg_stains) do
      add_foreign_key :sample_id, :samples
    end

  end
end
