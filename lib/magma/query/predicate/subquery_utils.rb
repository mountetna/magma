class Magma
  class SubqueryUtils
    def self.partition_args(predicate, query_args, preceding_predicate = "::and")
      subquery_args = []
      filter_args = []

      if query_args.is_a?(Array) && Magma::SubqueryUtils.is_subquery_query?(predicate, query_args)
        arry = []

        # BLAH, what is better than this?
        if preceding_predicate == "::or"
          arry << "full_outer"
        elsif preceding_predicate == "::and"
          # Inner join automatically applies an "AND"
          #   effect with subsequent filters.
          arry << "inner"
        end

        arry << query_args

        subquery_args << arry
        filter_args << query_args.last
      else
        filter_args = query_args
      end

      [subquery_args, filter_args]
    end

    def self.is_subquery_query?(predicate, query_args)
      verb, subquery_model_name, subquery_args = predicate.class.match_verbs(query_args, predicate, true)

      verb.gives?(:subquery)
    rescue Magma::QuestionError
      false
    end
  end
end
