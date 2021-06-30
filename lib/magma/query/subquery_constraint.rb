class Magma
  class SubqueryConstraint
    attr_reader :subquery_model, :filter, :parent_attribute, :condition

    def initialize(subquery_model, filter, parent_attribute, condition)
      @subquery_model = subquery_model
      @filter = filter
      @parent_attribute = parent_attribute
      @condition = condition
    end

    def apply(query)
      query = query.select(
        parent_attribute
      ).group_by(
        parent_attribute
      )

      constraints.each do |constraint|
        # Cannot seem to call methods in the having block.
        #   So we have to duplicate a bit of that logic, depending on
        #   the condition.
        case condition
        when "::every"
          query = every(query, constraint)
        when "::any"
          query = any(query, constraint)
        else
          raise ArgumentError, "Unknown condition, #{@condition}."
        end
      end

      query
    end

    def to_s
      @conditions.to_s
    end

    def hash
      @conditions.hash
    end

    def eql?(other)
      @conditions == other.conditions
    end

    private

    def condition_column(cond)
      cond.args.first.column
    end

    def condition_value(cond)
      cond.args.last
    end

    def constraints
      @constraints ||= @filter.flatten.map(&:constraint).inject(&:+)
    end

    def get_condition(constraint)
      constraint.conditions.first
    end

    def condition_parts(constraint)
      cond = get_condition(constraint)
      [condition_column(cond), condition_value(cond)]
    end

    def invert?(constraint)
      require 'pry'
      binding.pry
      get_condition(constraint).op.to_s.include?("NOT")
    end

    def every(query, constraint)
      column_name, value = condition_parts(constraint)

      # Because Sequel doesn't support `=` as a comparison operator, we'll
      #   modify this to invert the CASE and compare to < 1... i.e. == 0.
      return query.having do
               ## "Double invert" the 1 and 0 in this case
               sum(Sequel.case({ { column_name.to_sym => value } => 1 }, 0)) < 1
             end if invert?(constraint)

      query.having do
        sum(Sequel.case({ { column_name.to_sym => value } => 0 }, 1)) < 1
      end
    end

    def any(query, constraint)
      column_name, value = condition_parts(constraint)

      return query.having do
               sum(Sequel.case({ { column_name.to_sym => value } => 0 }, 1)) > 0
             end if invert?(constraint)

      query.having do
        sum(Sequel.case({ { column_name.to_sym => value } => 1 }, 0)) > 0
      end
    end
  end
end
