Sequel.migration do
  up do
    alter_table(:models) do
      add_column :version, Integer, default: 0
    end
  end

  down do
    alter_table(:models) do
      drop_column :version
    end
  end
end
