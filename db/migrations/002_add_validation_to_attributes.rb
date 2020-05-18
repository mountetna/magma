Sequel.migration do
  change do
    alter_table(:attributes) do
      add_column :validation, :json
    end
  end
end
