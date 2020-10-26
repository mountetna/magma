class Magma
  class MultiUpdate
    def initialize(model, records, src_id=nil, dest_id=nil)
      @model = model
      @records = records
      @src_id = src_id || model.identity.column_name
      @dest_id = dest_id || model.identity.column_name
    end

    def update
      return if @records.empty? || update_columns.empty?

      db.transaction do
        # Create a temporary table and drop when done, also copy the source
        # table structure (by Sequel model) onto the temp table.
        create_temp_table

        ensure_src_column

        # Insert the records into the temporary DB.
        insert_temp_records

        # Move the data from the temporary table into the original table.
        copy_temp_to_orig

        # Explicit drop, since ON COMMIT DROP doesn't seem to suffice
        drop_temp_table
      end
    end

    private

    def db
      Magma.instance.db
    end

    def create_temp_table
      db.run(
        <<-EOT
          CREATE TEMP TABLE #{temp_table_name}
          ON COMMIT DROP
          AS SELECT * FROM #{orig_table_name} WHERE 1=0;
        EOT
      )
    end

    def ensure_src_column
      return if @model.columns.include?(@src_id)
      db.run(
        <<-EOT
          ALTER TABLE #{temp_table_name}
          ADD COLUMN #{@src_id} integer;
        EOT
      )
    end

    def insert_temp_records
      db[temp_table_name].multi_insert(@records)
    end

    def copy_temp_to_orig
      column_alias = update_columns.map do |column|
        "#{column}=src.#{column}"
      end.join(', ')

      db.run(
        <<-EOT
          UPDATE #{orig_table_name} AS dest
          SET #{column_alias}
          FROM #{temp_table_name} AS src
          WHERE dest.#{@dest_id} = src.#{@src_id};
        EOT
      )
    end

    def drop_temp_table
      db.run(
        <<-EOT
          DROP TABLE #{temp_table_name};
        EOT
      )
    end

    def temp_table_name
      :"bulk_update_#{@model.project_name}_#{@model.model_name}"
    end

    def orig_table_name
      "#{@model.project_name}.#{@model.table_name.column}".to_sym
    end

    def update_columns
      @records.first.keys - [@src_id]
    end
  end
end
