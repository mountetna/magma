Sequel.migration do
  change do
    alter_table(Sequel[:labors][:monsters]) do
      add_column :certificates, :json
    end
  end
end
