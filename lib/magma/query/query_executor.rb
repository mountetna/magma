class Magma
  class QueryExecutor
    def initialize(query, timeout, db)
      @query = query
      @timeout = timeout
      @db = db

      raise ArgumentError, 'Timeout only works with postgres' if @timeout && @db.adapter_scheme != :postgres
    end

    def execute
      @timeout ? with_timeout { @db[@query.sql].all } : @db[@query.sql].all
    end

    private

    def with_timeout
      @db.transaction do
        @db.run("SET LOCAL statement_timeout = #{@timeout}")
        yield
      end
    end
  end
end
