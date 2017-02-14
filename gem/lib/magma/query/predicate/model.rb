class Magma
  class ModelPredicate < Magma::Predicate
  # This object takes several arguments:
  #   1) It can accept any of its attributes as arguments
  #      Here are the Magma attribute types:
  #        ChildAttribute - this returns another Model predicate
  #        CollectionAttribute
  #        TableAttribute - these both return a ModelList predicate
  #        DocumentAttribute - this returns a Document predicate
  #        ImageAttribute - this returns a Image predicate
  #        ForeignKey - this returns a Model predicate
  #        Attribute - this, depending on its type, can have different results
  #          If the type is a String, you get a String predicate
  #          If the type is an Integer or Float you get a Number predicate
  #          if the type is a DateTime you get a DateTime predicate
  #          if the type is a Boolean you get a Boolean predicate
  #   2) ::has
  #   3) ::identifier
    attr_reader :model

    def initialize model, argument, *predicates
      @model = model
      @argument = argument
      @predicates = predicates
      @child_predicate = get_child
    end

    def join 
      joins = []
      if @argument !~ /^::/
        case @attribute
        when Magma::ForeignKeyAttribute
          joins.push Magma::Question::Join.new(
            @attribute.link_model.table_name, 
            :id,
            @model.table_name, 
            @attribute.foreign_id
          )
        when Magma::TableAttribute, Magma::CollectionAttribute, Magma::ChildAttribute
          joins.push Magma::Question::Join.new(
            @attribute.link_model.table_name,
            @attribute.self_id,
            @model.table_name,
            :id
          )
        end
      end

      joins.concat super
    end

    def filter
      filters = []
      case @argument
      when "::has"
        case @attribute
        when Magma::ForeignKeyAttribute
          filters.push Magma::Question::Filter.new(
            "\"#{@model.table_name}\".\"#{@attribute.foreign_id}\" IS NOT NULL"
          )
        else
          filters.push Magma::Question::Filter.new(
            "\"#{@model.table_name}\".\"#{@attribute.name}\" IS NOT NULL"
          )
        end
      end
      filters.concat super
    end

    private

    def get_child
      if @argument == "::has"
        attribute_name = @predicates.shift
        @attribute = validate_attribute(attribute_name)
        return terminal(TrueClass)
      else
        attribute_name = @argument == "::identifier" ? @model.identity : @argument
        @attribute = validate_attribute(attribute_name)
        return get_attribute_child
      end
    end

    def get_attribute_child
      case @attribute
      when Magma::ChildAttribute, Magma::ForeignKeyAttribute
        return Magma::ModelPredicate.new(@attribute.link_model, *@predicates)
      when Magma::TableAttribute, Magma::CollectionAttribute
        return Magma::ModelListPredicate.new(@attribute.link_model, *@predicates)
      when Magma::DocumentAttribute, Magma::ImageAttribute
        return Magma::FilePredicate.new(@model, @attribute.name, *@predicates)
      else
        case @attribute.type.name
        when "String"
          return Magma::StringPredicate.new(@model, @attribute.name, *@predicates)
        when "Integer", "Float"
          return Magma::NumberPredicate.new(@model, @attribute.name, *@predicates)
        when "DateTime"
          return Magma::DateTimePredicate.new(@model, @attribute.name, *@predicates)
        else
          invalid_argument! attribute_name
        end
      end
    end

    private

    def validate_attribute attribute_name
      raise "No attribute given!" unless attribute_name
      raise "There is no such attribute #{attribute_name} on #{@model.name}!" unless @model.has_attribute? attribute_name
      return @model.attributes[attribute_name.to_sym]
    end
  end
end
