require_relative 'controller'


# We would like to know, given a query:
# 1) the chain of predicate types in the query.
#
class Predicate
  def initialize *predicates
    @predicates = predicates
  end

  private

  def invalid_argument! argument
    raise "Expected an argument to #{self}" if argument.nil?
    raise "#{argument} is not a valid argument to #{self}"
  end
end

class ModelListPredicate < Predicate
  # ModelList predicate - this is what the query will start with, probably
  #
  # "sample"
  #
  # This is a request for all objects of type "sample", so it's return type should be:
  #   [ Sample ]
  # 

  # This object takes several arguments:
  #   1) It can accept an arbitrary list of filters, which are
  #      in the form of lists, e.g.:
  #
  #      [ "patient", "experiment", "name", "::equals", "Colorectal" ]
  #      [ "patient", "clinical", "parameter", [ "name", "::equals", "Gender" ], "::first", "value", "::equals", "Male" ]
  #
  #      Each one of these filters must reduce to a Boolean, or else it is
  #      invalid.  They must come first.
  #
  #   2) It can be reduced by a list operator. The list operators are:
  #      ::any - a Boolean that returns true if the list is non-zero
  #      ::first - returns the first item in the list, namely a Model
  #      ::all - returns every item in the list, represented by a Model
  #      ::count - returns the number of items in the list

  def initialize model, *predicates
    @model = Magma.get_model model.to_sym
    @filters = []

    while argument = predicates.shift
      if argument.is_a? Array
        filter = Predicate.new(argument)
        @filters.push filter
      else
        break
      end
    end

    if argument
      @argument = argument
      @predicates = predicates
    else
      invalid_argument!
    end

    @filters.all do |filter|
      raise "Filter Predicate does not reduce to Boolean!" unless filter.reduce.is_a? Boolean
    end
  end

  def reduce
    case @argument.to_sym
    when :any
      return Boolean
    when :first
      return ModelPredicate.new(@model, *@predicates).reduce
    when :all
      return ModelPredicate.new(*@predicates).reduce
    when :count
      return Integer
    else
      invalid_argument! @argument
    end
  end
end

class ModelPredicate < Predicate
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
  def initialize model, argument, *predicates
    @model = model
    @argument = argument
    @predicates = predicates
    if @argument == "::has"
      attribute_name = predicates.shift
    else
      attribute_name = @argument
    end

    raise "No attribute given!" unless attribute_name
    raise "There is no such attribute #{attribute_name} on #{@model.name}!" unless @model.has_attribute? attribute_name

    @attribute = @model.attributes[attribute_name.to_sym]
  end

  def reduce
    case @argument
    when "::has"
      return Boolean
    else
      case @attribute
      when ChildAttribute
        return ModelPredicate.new(@attribute, *@predicates).reduce

        this returns another Model predicate
      when CollectionAttribute
      when TableAttribute - these both return a ModelList predicate
      when DocumentAttribute - this returns a Document predicate
      when ImageAttribute - this returns a Image predicate
      when ForeignKey - this returns a Model predicate
        Attribute - this, depending on its type, can have different results
          If the type is a String, you get a String predicate
          If the type is an Integer or Float you get a Number predicate
          if the type is a DateTime you get a DateTime predicate
          if the type is a Boolean you get a Boolean predicate
      end
    end
  end
end

class DocumentPredicate < Predicate
end

class ImagePredicate < Predicate
end

class StringPredicate < Predicate
end

class NumberPredicate < Predicate
end

class DateTimePredicate < Predicate
end

class BooleanPredicate < Predicate
end

#  Document, Model, String, Number, DateTime, Boolean
#
# Document
#



class DataTable
  def initialize query_json
    @query_json = query_json
  end

  # the first thing we should do is get the correct ROW SET. This yields a set of
  # row ID #s
  #
  # Then, when we have the row set, we can make a column map that reduces each row to
  # a value

  def rows
  end

  def to_matrix
  {
    # you need to name your samples
    name: @query_json["name"],
    matrix: {
      col_names: [],
      row_names: [],
      rows: rows
    }
  }
  end
end

class Magma
  class Server
    class Query < Magma::Server::Controller
      def response
        @data_tables = @params["queries"].map do |query_json|
          DataTable.new(query_json)
        end

        [ 200, {}, [ @data_tables.map(&:to_matrix).to_json ] ]
      end
    end
  end
end
