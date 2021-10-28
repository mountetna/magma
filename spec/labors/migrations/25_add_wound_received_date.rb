Sequel.migration do
  change do
    alter_table(Sequel[:labors][:wounds]) do
      add_column :received_date, DateTime
    end
  end
end
