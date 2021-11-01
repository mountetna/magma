class Magma
  class TableAttribute < Attribute
    include Magma::Link

    def query_to_payload(link)
      link ? link.map(&:last) : nil
    end

    def query_to_tsv(value)
      nil
    end

    def revision_to_links(record_name, new_ids)
      yield link_model, new_ids
    end

    def revision_to_payload(record_name, new_ids, loader)
      [
        name,
        new_ids.map do |id| loader.real_id(link_model, id) end
      ]
    end

    def entry(value, loader)
      nil
    end

    def missing_column?
      false
    end

    def load_hook(loader, record_name, new_ids, clean_records)
      return nil if loader.dry_run

      clean_records[record_name] = true
      return nil
    end

    def bulk_load_hook(loader, clean_records)
      return nil if loader.dry_run

      link_model.where(
        self_id => clean_records.keys.map do |id|
          loader.real_id(@magma_model, id)
        end
      ).delete unless clean_records.empty?

      return nil
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
