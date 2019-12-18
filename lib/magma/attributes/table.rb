class Magma
  class TableAttribute < Attribute
    include Magma::Link
    def initialize(name, model, opts)
      model.one_to_many(name, class: model.project_model(name), primary_key: :id)
      super
    end

    def query_to_payload(link)
      link&.map(&:last)
    end

    def query_to_tsv(value)
      nil
    end

    def revision_to_loader(record_name, new_value)
      nil
    end

    def revision_to_payload(record_name, value)
    end

    class Validation < Magma::CollectionAttribute::Validation; end
  end
end
