class Magma
  class SubqueryUtils
    def self.subquery_type(verb)
      case verb
      when "::or"
        "full_outer"
      else
        "inner"
      end
    end

    def self.partition_args(predicate, query_args, preceding_predicate = nil)
      subquery_args = []
      filter_args = []

      if query_args.is_a?(Array) && Magma::SubqueryUtils.is_subquery_query?(predicate, query_args)
        subquery_args << [self.subquery_type(preceding_predicate), query_args]
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
