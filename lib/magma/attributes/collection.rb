class Magma
  class CollectionAttribute < Attribute
    include Magma::Link
    def initialize(name, model, opts)
      model.one_to_many(name, class: model.project_model(name), primary_key: :id)
      super
    end
    def json_payload(link)
      link ? link.map(&:last).sort : nil
    end

    def text_payload(value)
      json_payload(value).join(", ")
    end

    def update(record_name, new_ids)
      nil
    end

    def update_links(record_name, new_ids)
      yield link_model, new_ids
    end

    def update_payload(record_name, value)
      [ @name, value.zip(value) ]
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
