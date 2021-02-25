require 'json'

class Magma
  class FileCollectionPredicate < Magma::ColumnPredicate
    def initialize question, model, alias_name, attribute, *query_args
      super
      @md5s = MD5Set.new(@question.user, @model)
    end

    verb '::url' do
      child String

      extract do |table, identity|
        table.first[column_name] ? table.first[column_name].map do |f|
          Magma.instance.storage.download_url(
            @model.project_name,
            f["filename"]
          ).to_s
        end : nil
      end
    end

    verb '::path' do
      child String

      extract do |table, identity|
        table.first[column_name] ? table.first[column_name].map { |f| f["filename"] } : nil
      end
    end

    verb '::original_filename' do
      child String

      extract do |table, identity|
        table.first[column_name] ? table.first[column_name].map { |f| f["original_filename"] } : nil
      end
    end

    verb '::md5' do
      child String

      extract do |table, identity|
        table.first[column_name]&.map { |f| @md5s << f["filename"] }
      end
    end

    verb '::all' do
      child String

      extract do |table, identity|
        table.first[column_name] ? table.first[column_name].map do |f|
          f.symbolize_keys.update({
            url: Magma.instance.storage.download_url(
              @model.project_name,
              f["filename"]
            ).to_s
          })
        end : nil
      end
    end

    def select
      [ Sequel[alias_name][@column_name].as(column_name) ]
    end
  end
end
