class Magma
  class StartPredicate < Magma::ModelPredicate
    def self.verbs
      Magma::ModelPredicate.verbs.merge(@verbs)
    end

    verb '::attribute_names' do
      child Array

      extract do
        @model.attributes.keys
      end

      format { [ 'String' ] }
    end

    def add_filters
      super

      # filter out disconnected records
      if @question.show_disconnected?
        filters = []
        each_ancestor do |disc_model, ancestors|
          if disc_model.parent_model
            filters.push(ancestors + [ '::lacks', disc_model.parent_model_name ])
          end
        end
        create_filter([ '::or', *filters ])
      else
        each_ancestor do |disc_model, ancestors|
          if disc_model.parent_model
            create_filter(ancestors + [ '::has', disc_model.parent_model_name ])
          end
        end
      end
    end
  end
end
