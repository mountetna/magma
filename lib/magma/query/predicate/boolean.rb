class Magma
  class BooleanPredicate < Magma::ColumnPredicate
    private

    def get_child
      case @argument
      when "::true"
      when "::false"
      when "::null"
        return terminal(TrueClass)
      else
        invalid_argument! @argument
      end
    end
  end
end
