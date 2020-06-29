class Magma
  class CollectionAttribute < Attribute
    include Magma::Link
    def initialize(name, model, opts)
      model.one_to_many(name, class: model.project_model(name), primary_key: :id)
      super
    end
    def query_to_payload(link)
      link ? link.map(&:last).sort : nil
    end

    def query_to_tsv(value)
      query_to_payload(value).join(", ")
    end

    def revision_to_loader(record_name, new_ids)
      nil
    end

    def revision_to_links(record_name, new_ids)
      yield link_model, new_ids
    end

    def revision_to_payload(record_name, value)
      [ @name, value ]
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
  end
end
