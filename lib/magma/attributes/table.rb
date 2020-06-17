class Magma
  class TableAttribute < Attribute
    include Magma::Link
    def initialize(opts = {})
      super
      set_one_to_many if @magma_model
    end

    def magma_model=(new_magma_model)
      super
      set_one_to_many
    end

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

    def set_one_to_many
      @magma_model.one_to_many(
        attribute_name.to_sym,
        class: @magma_model.project_model(attribute_name),
        primary_key: :id
      )
    end
  end
end
