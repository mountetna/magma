class Magma
  class RecordPredicate < Magma::Predicate
  # This object takes several arguments:
  #   1) It can accept any of its attributes as arguments
  #      Here are the Magma attribute types:
  #        ChildAttribute - this returns another Record predicate
  #        CollectionAttribute
  #        TableAttribute - these both return a Model predicate
  #        DocumentAttribute - this returns a Document predicate
  #        ImageAttribute - this returns a Image predicate
  #        ForeignKey - this returns a Record predicate
  #        Attribute - this, depending on its type, can have different results
  #          If the type is a String, you get a String predicate
  #          If the type is an Integer or Float you get a Number predicate
  #          if the type is a DateTime you get a DateTime predicate
  #          if the type is a Boolean you get a Boolean predicate
  #   2) ::has
  #   3) ::identifier
    attr_reader :model

    def initialize model, alias_name, argument, *predicates
      @model = model
      @alias_name = alias_name
      @argument = argument
      @predicates = predicates
      @child_predicate = get_child
    end

    def join 
      if @argument !~ /^::/
        case @attribute
        when Magma::ForeignKeyAttribute
          return [
            Magma::Question::Join.new(
              @child_predicate.table_name,
              @child_predicate.alias_name,
              :id,
              table_name,
              alias_name,
              @attribute.foreign_id
            )
          ]
        when Magma::TableAttribute, Magma::CollectionAttribute, Magma::ChildAttribute
          return [
            Magma::Question::Join.new(
              @child_predicate.table_name,
              @child_predicate.alias_name,
              @attribute.self_id,
              table_name,
              alias_name,
              :id
            )
          ]
        end
      end
      super
    end

    def to_hash
      super.merge(
        model: model
      )
    end

    def constraint
      case @argument
      when "::has"
        case @attribute
        when Magma::ForeignKeyAttribute
          return [
            Magma::Question::Constraint.new(
              "\"#{alias_name}\".\"#{@attribute.foreign_id}\" IS NOT NULL"
            )
          ]
        else
          return [
            Magma::Question::Constraint.new(
              "\"#{alias_name}\".\"#{@attribute.name}\" IS NOT NULL"
            )
          ]
        end
      end
      super
    end

    private

    def get_child
      if @argument == "::has"
        attribute_name = @predicates.shift
        @attribute = validate_attribute(attribute_name)
        return terminal(TrueClass)
      elsif @argument == "::metrics"
        return Magma::MetricsPredicate.new(@model, alias_name, *@predicates)
      elsif @argument.is_a?(Array)
        return Magma::VectorPredicate.new(@model, alias_name, @argument, *@predicates)
      else
        attribute_name = @argument == "::identifier" ? @model.identity : @argument
        @attribute = validate_attribute(attribute_name)
        return get_attribute_child
      end
    end

    def get_attribute_child
      case @attribute
      when :id
        return Magma::NumberPredicate.new(@model, alias_name, @attribute, *@predicates)
      when Magma::ChildAttribute, Magma::ForeignKeyAttribute
        return Magma::RecordPredicate.new(@attribute.link_model, nil, *@predicates)
      when Magma::TableAttribute, Magma::CollectionAttribute
        return Magma::ModelPredicate.new(@attribute.link_model, *@predicates)
      when Magma::DocumentAttribute, Magma::ImageAttribute
        return Magma::FilePredicate.new(@model, alias_name, @attribute.name, *@predicates)
      else
        case @attribute.type.name
        when "String"
          return Magma::StringPredicate.new(@model, alias_name, @attribute.name, *@predicates)
        when "Integer", "Float"
          return Magma::NumberPredicate.new(@model, alias_name, @attribute.name, *@predicates)
        when "DateTime"
          return Magma::DateTimePredicate.new(@model, alias_name, @attribute.name, *@predicates)
        when "TrueClass"
          return Magma::BooleanPredicate.new(@model, alias_name, @attribute.name, *@predicates)
        else
          invalid_argument! @attribute.name
        end
      end
    end

    private

    def validate_attribute attribute_name
      raise ArgumentError, "No attribute given!" unless attribute_name
      raise ArgumentError, "There is no such attribute #{attribute_name} on #{@model.name}!" unless @model.has_attribute?(attribute_name) || (@argument == "::identifier" && attribute_name == :id)
      return :id if attribute_name == :id
      return @model.attributes[attribute_name.to_sym]
    end
  end
end
