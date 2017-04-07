class Magma
  class FilePredicate < Magma::Predicate
    def initialize model, attribute_name, argument, *predicates
      @model = model
      @attribute_name = attribute_name
      @argument = argument
      @predicates = predicates
      @child_predicate = get_child
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
