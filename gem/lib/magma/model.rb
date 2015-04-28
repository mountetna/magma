class Magma
  Model = Class.new(Sequel::Model)
  class Model
    class << self
      def validate
        raise "Missing table for #{name}." unless Magma.instance.db.table_exists? table_name
      end

      def suggest_migration
        if Magma.instance.db.table_exists? table_name
          suggest_table_update
        else
          suggest_table_creation
        end
      end

      private
      def suggest_table_creation
        migration = Magma::Migration.new
        migration.change %Q!
          create_table(:#{table_name}) do
            primary_key :id
          end
          !
        puts migration
      end
      
      def suggest_table_update
        migration = Magma::Migration.new
        migration.change %Q!
          create_table(:#{table_name}) do
            primary_key :id
            #{suggest_missing_attributes}
          end
          !
        puts migration
      end
    end
  end
end
