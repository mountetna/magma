require_relative "./date_time_attribute"
require_relative "./date_time_shifter"

class Magma
  class ShiftedDateTimeAttribute < Magma::DateTimeAttribute
    def revision_to_loader(record_name, new_value)
      # record = @magma_model. #find by record_name??
      require "pry"
      binding.pry
      date_time_shifter = Magma::DateTimeShifter.new(
        salt: Magma.instance.config(:dateshift_salt),
        record: record,
      )

      [name, new_value ? date_time_shifter.shifted_value(new_value) : nil]
    end

    def revision_to_payload(record_name, new_value, loader)
      # Do we need this?
      [name, new_value]
    end
  end
end
