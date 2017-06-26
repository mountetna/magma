Sequel.migration do
  up do
    alter_table(:samples) do
      set_column_type :ice_time, 'double precision USING null'
      set_column_type :fixation_time, 'double precision USING null'
    end
  end
  down do
    alter_table(:samples) do
      set_column_type :ice_time, 'timestamp without time zone USING null'
      set_column_type :fixation_time, 'timestamp without time zone USING null'
    end
  end
end
