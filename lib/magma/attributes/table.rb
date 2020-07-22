class Magma
  class TableAttribute < Attribute
    include Magma::Link

    def query_to_payload(link)
      link ? link.map(&:last) : nil
    end

    def query_to_tsv(value)
      nil
    end

    def revision_to_loader(record_name, new_value)
      nil
    end

    def revision_to_links(record_name, new_ids)
      yield link_model, new_ids
    end

    def revision_to_payload(record_name, value, user)
    end

    def missing_column?
      false
    end

    class Validation < Magma::CollectionAttribute::Validation; end

    private

    def after_magma_model_set
      @magma_model.one_to_many(
        attribute_name.to_sym,
        class: @magma_model.project_model(attribute_name),
        primary_key: :id
      )
    end
  end
end
