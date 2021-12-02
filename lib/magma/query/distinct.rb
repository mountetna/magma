class Magma
  class Distinct
    attr_reader :table_alias

    def initialize(table_alias)
      @table_alias = table_alias
    end

    def apply(query)
      query.distinct.unordered
    end
  end
end
