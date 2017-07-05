Sequel.migration do
  change do
    alter_table(:projects) do
      add_column :whats_new, String
      add_column :faq, String
    end
  end
end
