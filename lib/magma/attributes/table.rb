class Magma
  class TableAttribute < Attribute
    include Magma::Link
    def initialize(name, model, opts)
      model.one_to_many(name, class: model.project_model(name), primary_key: :id)
      super
    end

    def json_payload(link)
      link ? link.map(&:last) : nil
    end

    def text_payload(value)
      nil
    end

    def update(new_value)
      nil
    end

    class Validation < Magma::CollectionAttribute::Validation; end
  end
end
