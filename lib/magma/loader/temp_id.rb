class Magma
  class TempId
    # This marks the column as a temporary id. It needs to be replaced with a
    # real foreign key id for the corresponding object once it is complete.
    attr_reader :obj, :id
    attr_accessor :record_entry

    def initialize(id, obj)
      @obj = obj
      @id = id
    end

    def real_id
      return nil if record_entry.nil?
      record_entry.real_id
    end
  end
end
