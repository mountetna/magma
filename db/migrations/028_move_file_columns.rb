Sequel.migration do
  up do
    alter_table(:samples) do
      add_column :treg_file, String
      add_column :nktb_file, String
      add_column :sort_file, String
      add_column :dc_file, String
    end

    # now move it between columns
    execute "UPDATE samples as s
      SET treg_file = t.facs_file
      FROM treg_stains as t 
      WHERE s.id = t.sample_id"

    execute "UPDATE samples as s
      SET nktb_file = t.facs_file
      FROM nktb_stains as t 
      WHERE s.id = t.sample_id"

    execute "UPDATE samples as s
      SET sort_file = t.facs_file
      FROM sort_stains as t 
      WHERE s.id = t.sample_id"

    execute "UPDATE samples as s
      SET dc_file = t.facs_file
      FROM dc_stains as t 
      WHERE s.id = t.sample_id"

    drop_table :nktb_stains
    drop_table :treg_stains
    drop_table :dc_stains
    drop_table :sort_stains
  end
  down do
  end
end
