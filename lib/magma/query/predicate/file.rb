class Magma
  class FilePredicate < Magma::ColumnPredicate
    verb '::url' do
      child String

      extract do |table, identity|
        Magma.instance.storage.download_url(
          @model.project_name, table.first[column_name]
        )
      end
    end

    verb '::path' do
      child String
    end

    def select
      [ Sequel[alias_name][@attribute_name].as(column_name) ]
    end
  end
end
