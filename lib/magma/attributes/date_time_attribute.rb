class Magma
  class DateTimeAttribute < Attribute
    def database_type
      DateTime
    end

    def revision_to_loader(record_name, new_value)
      [ name, DateTime.parse(new_value) ]
    end
  end
end
