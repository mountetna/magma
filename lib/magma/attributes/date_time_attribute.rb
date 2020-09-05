class Magma
  class DateTimeAttribute < Attribute
    def database_type
      DateTime
    end

    def revision_to_loader(record_name, new_value)
      [ name, new_value ? DateTime.parse(new_value) : nil ]
    end
  end
end
