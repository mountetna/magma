class Magma
  class TableAttribute < Attribute
    include Magma::Link
    def json_for record
      link = record[name]
      link ? link.map(&:last) : nil
    end

    def txt_for record
      nil
    end

    def update_record record, new_value
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
