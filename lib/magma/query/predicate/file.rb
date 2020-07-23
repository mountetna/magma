class Magma
  class FilePredicate < Magma::ColumnPredicate
    verb '::url' do
      child String

      extract do |table, identity|
        Magma.instance.storage.download_url(
          @model.project_name,
          table.first[column_name] ? table.first[column_name]["filename"] : nil
        )
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
