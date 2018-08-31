class Magma
  class TableAttribute < Attribute
    include Magma::Link
    def json_for record
      link = record[@name]
      link ? link.map(&:last) : nil
    end

    def txt_for record
      nil
    end

    def update record, new_value
    end
  end
end
