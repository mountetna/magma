Sequel.migration do
    change do
      alter_table(Sequel[:labors][:monsters]) do
        set_column_type :stats, :json
      end
    end
  end
