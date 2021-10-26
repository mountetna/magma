require_relative "./date_time_attribute"
require_relative "./date_time_shifter"

class Magma
  class ShiftedDateTimeAttribute < Magma::DateTimeAttribute
    def patch_record_load_hook(loader, record_name, record)
      path_to_root = loader.path_to_date_shift_root(@magma_model, record_name)

      return "#{record_name} is not connected to the date-shift root" if path_to_root.empty?

      date_time_shifter = Magma::DateTimeShifter.new(
        salt: Magma.instance.config(:dateshift_salt)&.to_s,
        date_shift_root_record_name: path_to_root.last,
      )

      record[self.name] = date_time_shifter.shifted_value(record[self.name])

      nil
    rescue ArgumentError => e
      Magma.instance.logger.log_error(e)
      return e.message
    end
  end
end
