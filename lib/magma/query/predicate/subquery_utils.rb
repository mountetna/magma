class Magma
  class SubqueryUtils
    def self.subquery_type(verb)
      case verb
      when '::or'
        'full_outer'
      else
        'inner'
      end
    end

    def self.partition_args(predicate, query_args, preceding_predicate = nil)
      subquery_args = []
      filter_args = []

      if query_args.is_a?(Array) && Magma::SubqueryUtils.is_subquery_query?(predicate, query_args)
        arry = []

        arry << self.subquery_type(preceding_predicate)
        arry << query_args

        subquery_args << arry
        filter_args << query_args.last
      else
        filter_args = query_args
      end

      [self.remove_empty(subquery_args), self.remove_empty(filter_args)]
    end

    def self.is_subquery_query?(predicate, query_args)
      verb, subquery_model_name, subquery_args = predicate.class.match_verbs(query_args, predicate, true)

      verb.gives?(:subquery)
    rescue Magma::QuestionError
      false
    end

    private

    def self.remove_empty(args)
      arry = []

      args.each do |arg|
        arry << arg unless is_empty?(arg)
      end

      arry
    end

    def self.is_empty?(args)
      args.is_a?(Array) && args.length == 1 && ['::and', '::or', '::any', '::every'].include?(args.first)
    end
  end
end
