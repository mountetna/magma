Sequel.migration do
  up do
    alter_table(:models) do
      add_column :date_shift_root, TrueClass, default: false
    end
  end

  down do
    alter_table(:models) do
      drop_column :date_shift_root
    end
  end
end
