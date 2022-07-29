class Magma
  class CollectionAttribute < Attribute
    include Magma::Link

    def query_to_payload(link)
      link ? link.map(&:last).sort : nil
    end

    def query_to_tsv(value)
      value.join(", ")
    end

    def revision_to_links(record_name, new_ids)
      yield link_model, new_ids
    end

    def entry(value, loader)
      nil
    end

    def missing_column?
      false
    end

    class Validation < Magma::Validation::Attribute::BaseAttributeValidation
      def validate(value, &block)
        unless value.is_a?(Array)
          yield "#{value} is not an Array."
          return
        end
        value.each do |link|
          next unless link
          link_validate(link,&block)
        end
      end
    end

    def after_magma_model_set
      @magma_model.one_to_many(
        attribute_name.to_sym,        
        class: @magma_model.project_model(link_model_name),
        primary_key: :id,
        key: "#{link_attribute_name}_id".to_sym
      )
    end
  end
end
