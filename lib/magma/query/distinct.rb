class Magma
  class Distinct
    def initialize(column_name)
      @column_name = column_name
    end

    def apply(query)
      query.distinct.order(@column_name)
    end
  end
end
