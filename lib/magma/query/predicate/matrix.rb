class Magma
  class MatrixPredicate < Magma::ColumnPredicate
    verb '::slice', Array do
      child do
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
