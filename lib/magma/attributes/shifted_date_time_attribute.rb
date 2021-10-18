require_relative "./date_time_attribute"
require_relative "./date_time_shifter"

class Magma
  class ShiftedDateTimeAttribute < Magma::DateTimeAttribute
    # def revision_to_loader(record_name, new_value)
    #   # record = @magma_model. #find by record_name??
    #   require "pry"
    #   binding.pry
    #   date_time_shifter = Magma::DateTimeShifter.new(
    #     salt: Magma.instance.config(:dateshift_salt),
    #     record: record,
    #   )

    #   [name, new_value ? date_time_shifter.shifted_value(new_value) : nil]
    # end

    # def revision_to_payload(record_name, new_value, loader)
    #   # Do we need this?
    #   [name, new_value]
    # end

    # class Validation < Magma::Validation::Attribute::BaseAttributeValidation
    #   def validate_shift(record_name, document, value, &block)
    #     return if value.nil? || value.empty?
    #     # For insert records, ensure that a parent is provided.
    #     #   If a parent is not included in the revision, reject.
    #     #   If a parent is provided, but no date-shift-root-record found, reject.    
    #     # For update records, if no date-shift-root-record found, reject.
    #     validate_date_shift_root_record(record_name, document, &block)
    #     validate_
    #     validate_shifted_date_time_insert(record_name, document, &block)
    #   end

    #   private
    # end
  end
end
