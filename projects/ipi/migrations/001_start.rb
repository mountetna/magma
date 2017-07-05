Sequel.migration do
  change do
    
          create_table(:patients) do
            primary_key :id
          end
          
  end
end
