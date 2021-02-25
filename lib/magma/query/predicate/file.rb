require_relative '../md5_set'

class Magma
  class FilePredicate < Magma::ColumnPredicate
    def initialize question, model, alias_name, attribute, *query_args
      super
      @md5s = MD5Set.new(@question.user, @model)
    end

    attr_reader :requested_md5_paths
    verb '::url' do
      child String

      extract do |table, identity|
        table.first[column_name] ? Magma.instance.storage.download_url(
          @model.project_name,
          table.first[column_name]["filename"]
        ) : nil
      end
    end


    class MD5Value
      def initialize(predicate, file)
        @predicate = predicate
        @file = file

        @predicate.requested_md5_paths << file
      end
    end

    verb '::md5' do
      child String

      extract do |table, identity|
        table.first[column_name] ? (@md5s << table.first[column_name]["filename"]) : nil
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
