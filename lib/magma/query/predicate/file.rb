require_relative '../metis_metadata'

class Magma
  class FilePredicate < Magma::ColumnPredicate
    def initialize question, model, alias_name, attribute, *query_args
      super
      @metis_metadata = MetisMetadata.new(@question.user, @model)
    end

    attr_reader :requested_file_paths
    verb '::url' do
      child String

      extract do |table, identity|
        table.first[column_name] ? Magma.instance.storage.download_url(
          @model.project_name,
          table.first[column_name]["filename"]
        ) : nil
      end
    end


    class MetisMetadataValue
      def initialize(predicate, file)
        @predicate = predicate
        @file = file

        @predicate.requested_file_paths << file
      end
    end

    verb '::md5' do
      child String

      extract do |table, identity|
        table.first[column_name] ? (@metis_metadata << table.first[column_name]["filename"])[:file_hash] : nil
      end
    end

    verb '::updated_at' do
      child String

      extract do |table, identity|
        table.first[column_name] ? (@metis_metadata << table.first[column_name]["filename"])[:updated_at] : nil
      end
    end

    verb '::path' do
      child String

      extract do |table, identity|
        table.first[column_name] ? table.first[column_name]["filename"] : nil
      end
    end

    verb '::original_filename' do
      child String

      extract do |table, identity|
        table.first[column_name] ? table.first[column_name]["original_filename"] : nil
      end
    end

    verb '::all' do
      child String

      extract do |table, identity|
        table.first[column_name] ? table.first[column_name].symbolize_keys : nil
      end
    end

    def select
      [ Sequel[alias_name][@column_name].as(column_name) ]
    end
  end
end
