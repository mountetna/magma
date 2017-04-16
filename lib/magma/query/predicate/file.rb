class Magma
  class FilePredicate < Magma::ColumnPredicate

    def select
      [ :"#{column_name}___#{column_name}" ]
    end

    private

    def get_child
      case @argument
      when "::url"
        return terminal(String)
      when "::path"
        return terminal(String)
      else
        invalid_argument! @argument
      end
    end
  end
end
