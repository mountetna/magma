class Magma
  class Join
    attr_reader :constraints

    attr_reader :right_table_alias, :left_table_alias

    def initialize(lt, lt_alias, lt_id, rt, rt_alias, rt_id, inner_join: false)
      @right_table = rt
      @right_table_alias = rt_alias.to_sym
      @right_table_id = rt_id.to_sym

      @left_table = lt
      @left_table_alias = lt_alias.to_sym
      @left_table_id = lt_id.to_sym

      @constraints = [
        { left_table_column => right_table_column }
      ]

      @inner_join = inner_join
    end

    def apply query
      if @inner_join
        query.inner_join(
          Sequel.as(@right_table,@right_table_alias),
          Sequel.&(
            *@constraints
          )
        )
      else
        query.left_outer_join(
          Sequel.as(@right_table,@right_table_alias),
          Sequel.&(
            *@constraints
          )
        )
      end
    end

    def to_s
      @constraints.to_s
    end

    def right_table_column
      Sequel.qualify(@right_table_alias, @right_table_id)
    end

    def left_table_column
      Sequel.qualify(@left_table_alias, @left_table_id)
    end

    def hash
      right_table_column.hash + left_table_column.hash
    end

    def eql?(other)
      right_table_column == other.right_table_column && left_table_column == other.left_table_column
    end
  end
end
