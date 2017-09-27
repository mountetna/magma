class Magma
  class FilePredicate < Magma::ColumnPredicate
    verb "::url" do
      child String
    end

    verb "::path" do
      child String
    end

    def select
      [ Sequel[alias_name][@attribute_name].as(column_name) ]
    end
  end
end
