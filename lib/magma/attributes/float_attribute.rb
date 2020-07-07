class Magma
  class FloatAttribute < Attribute
    def database_type
      Float
    end

    def revision_to_loader(record_name, new_value)
      [ name, new_value.to_f ]
    end
  end
end
