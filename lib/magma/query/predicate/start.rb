class Magma
  class StartPredicate < Magma::ModelPredicate
    def self.verbs
      Magma::ModelPredicate.verbs
    end

    def add_filters
      super

      # filter out disconnected records
      unless @question.show_disconnected?
        each_ancestor do |disc_model, ancestors|
          if disc_model.parent_model
            create_filter(ancestors + [ '::has', disc_model.parent_model_name ])
          end
        end
      end
    end
  end
end
