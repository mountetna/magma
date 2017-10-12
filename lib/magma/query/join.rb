class Magma
  class Join
    def initialize(t1, t1_alias, t1_id, t2, t2_alias, t2_id)
      @table1 = t1
      @table1_alias = t1_alias.to_sym
      @table1_id = t1_id.to_sym
      @table2_alias = t2_alias.to_sym
      @table2_id = t2_id.to_sym
    end

    def apply query
      query.left_outer_join(
        Sequel.as(@table1,@table1_alias),
        table1_column => table2_column
      )
    end

    def to_s
      {table1_column=> table2_column}.to_s
    end

    def table1_column
      Sequel.qualify(@table1_alias, @table1_id)
    end

    def table2_column
      Sequel.qualify(@table2_alias, @table2_id)
    end

    def hash
      table1_column.hash + table2_column.hash
    end

    def eql?(other)
      table1_column == other.table1_column && table2_column == other.table2_column
    end
  end
end
