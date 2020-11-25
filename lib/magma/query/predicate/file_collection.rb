require 'json'

class Magma
  class FileCollectionPredicate < Magma::ColumnPredicate
    verb '::url' do
      child String

      extract do |table, identity|
        table.first[column_name] ? table.first[column_name].map do |f|
          Magma.instance.storage.download_url(
            @model.project_name,
            f["filename"]
          )
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

    verb '::all' do
      child String

      extract do |table, identity|
        table.first[column_name] ? table.first[column_name].map do |f|
          f.symbolize_keys.update({
            url: Magma.instance.storage.download_url(
              @model.project_name,
              f["filename"]
            )
          })
        end : nil
      end
    end

    def select
      [ Sequel[alias_name][@column_name].as(column_name) ]
    end
  end
end
