class Magma
  class Constraint
    attr_reader :conditions, :table_alias

    def initialize(table_alias, *args)
      @table_alias = table_alias
      @conditions = args
    end

    def apply(query)
      query.where(*@conditions)
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
  end
end
