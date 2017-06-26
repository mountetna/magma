Sequel.migration do
  change do
    alter_table(:patients) do
      add_column :flow_pdf, String
    end
  end
end
