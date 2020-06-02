class Magma
  class FilePredicate < Magma::ColumnPredicate
    verb '::url' do
      child String

      extract do |table, identity|
        Magma.instance.storage.download_url(
          @model.project_name, JSON.parse(table.first[column_name])["path"]
        )
      end
    end

    verb '::path' do
      child String

      extract do |table, identity|
        JSON.parse(table.first[column_name])["path"]
      end
    end

    verb '::original_filename' do
      child String

      extract do |table, identity|
        JSON.parse(table.first[column_name])["original_filename"]
      end
    end

    def select
      [ Sequel[alias_name][@attribute_name].as(column_name) ]
    end
  end
end
