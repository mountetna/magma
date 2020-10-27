class Magma
  class StartPredicate < Magma::ModelPredicate
    def self.verbs
      Magma::ModelPredicate.verbs
    end

    def add_filters
      super

      # filter out orphans
      unless @question.show_orphans?
        each_ancestor do |orphan_model, ancestors|
          if orphan_model.parent_model
            create_filter(ancestors + [ '::has', orphan_model.parent_model_name ])
          end
        end
      end
    end
  end
end
