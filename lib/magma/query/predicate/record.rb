class Magma
  class RecordPredicate < Magma::Predicate
  # This object takes several arguments:
  #   1) It can accept any of its attributes as arguments
  #      Here are the Magma attribute types:
  #        ChildAttribute - this returns another Record predicate
  #        CollectionAttribute
  #        TableAttribute - these both return a Model predicate
  #        FileAttribute - this returns a File predicate
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

    def initialize question, model, alias_name, *query_args
      super(question)
      @model = model
      @alias_name = alias_name
      process_args(query_args)
    end

    verb '::identifier' do
      child do
        attribute_child(@model.identity)
      end
    end

    verb '::has', :attribute_name do
      child TrueClass

      constraint do
        attribute = valid_attribute(@arguments[1])
        case attribute
        when Magma::ForeignKeyAttribute
          not_null_constraint(attribute.foreign_id)
        else
          not_null_constraint(attribute.name)
        end
      end
    end

    verb '::lacks', :attribute_name do
      child TrueClass

      constraint do
        attribute = valid_attribute(@arguments[1])
        case attribute
        when Magma::ForeignKeyAttribute
          basic_constraint(attribute.foreign_id, nil)
        else
          basic_constraint(attribute.name, nil)
        end
      end
    end

    verb '::metrics' do
      child do
        Magma::MetricsPredicate.new(@question, @model, alias_name, *@query_args)
      end
    end

    verb :attribute_name do
      child do
        attribute_child(@arguments[0])
      end
      join :attribute_join
    end

    verb Array do
      child do
        Magma::TablePredicate.new(@question, @model, alias_name, @arguments[0], *@query_args)
      end
    end

    def to_hash
      super.merge(
        model: model
      )
    end

    private

    def attribute_name(argument)
      @model.has_attribute?(argument) || argument == :id
    end

    def attribute_join
      attribute = valid_attribute(@arguments[0])
      case attribute
      when Magma::ForeignKeyAttribute
        return Magma::Join.new(
          # left table
          table_name,
          alias_name,
          attribute.foreign_id,

          #right table
          @child_predicate.table_name,
          @child_predicate.alias_name,
          :id
        )
      when Magma::TableAttribute, Magma::CollectionAttribute, Magma::ChildAttribute
        return Magma::Join.new(
          #left table
          table_name,
          alias_name,
          :id,

          #right table
          @child_predicate.table_name,
          @child_predicate.alias_name,
          attribute.self_id,
        )
      end
    end

    def attribute_child(attribute_name)
      attribute = valid_attribute(attribute_name)
      if @question.restrict? && attribute.respond_to?(:restricted) && attribute.restricted
        raise Etna::Forbidden, "Cannot query for restricted attribute #{attribute_name}"
      end
      case attribute
      when :id
        return Magma::NumberPredicate.new(@question, @model, alias_name, attribute, *@query_args)
      when Magma::ChildAttribute, Magma::ForeignKeyAttribute
        return Magma::RecordPredicate.new(@question, attribute.link_model, nil, *@query_args)
      when Magma::TableAttribute, Magma::CollectionAttribute
        return Magma::ModelPredicate.new(@question, attribute.link_model, *@query_args)
      when Magma::FileAttribute, Magma::ImageAttribute
        return Magma::FilePredicate.new(@question, @model, alias_name, attribute.name, *@query_args)
      when Magma::MatchAttribute
        return Magma::MatchPredicate.new(@question, @model, alias_name, attribute.name, *@query_args)
      when Magma::MatrixAttribute
        return Magma::MatrixPredicate.new(@question, @model, alias_name, attribute.name, *@query_args)
      when Magma::StringAttribute
        return Magma::StringPredicate.new(@question, @model, alias_name, attribute.name, *@query_args)
      when Magma::IntegerAttribute, Magma::FloatAttribute
        return Magma::NumberPredicate.new(@question, @model, alias_name, attribute.name, *@query_args)
      when Magma::DateTimeAttribute
        return Magma::DateTimePredicate.new(@question, @model, alias_name, attribute.name, *@query_args)
      when Magma::BooleanAttribute
        return Magma::BooleanPredicate.new(@question, @model, alias_name, attribute.name, *@query_args)
      else
        invalid_argument! attribute.name
      end
    end

    def valid_attribute attribute_name
      attribute_name == :id ? :id : @model.attributes[attribute_name.to_sym]
    end
  end
end
