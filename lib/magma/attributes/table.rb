class Magma
  class TableAttribute < Attribute
    include Magma::Link
    def initialize(name, model, opts)
      model.one_to_many(name, class: model.project_model(name), primary_key: :id)
      super
    end

    def json_for record
      link = record[@name]
      link ? link.map(&:last) : nil
    end

    def txt_for record
      nil
    end

    def update record, new_value
    end

    def missing_column?
      false
    end

    class Validation < Magma::CollectionAttribute::Validation; end
  end
end
