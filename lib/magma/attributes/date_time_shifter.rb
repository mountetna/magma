class Magma
  class DateTimeShiftError < StandardError
  end

  class DateTimeShifter
    def initialize(salt:, record_name:, magma_model:)
      raise DateTimeShiftError, ":salt is required" if salt.nil? || salt.empty?

      @salt = salt
      @record_name = record_name
      @magma_model = magma_model
    end

    def offset_id
      return @record_name if @magma_model.is_date_shift_root?

      @date_shift_root_record = date_shift_root_record

      raise DateTimeShiftError, "No date shift root record found." unless @date_shift_root_record

      @date_shift_root_record.identifier
    end

    def offset_days
      # the offset in days is computed from hmac of the record_id
      signature = OpenSSL::HMAC.hexdigest(
        "SHA256",
        @salt,
        offset_id
      )

      # we convert the hexadecimal string to a number in base 16.
      # A 64-character hex string becomes a 32 byte, 256 bit number
      # Divide by 2^256 to get a number between 0 and 1
      signature_fraction = signature.to_i(16).to_f / (1 << 256)

      # offset days are computed as a number from 0 to 364
      (signature_fraction * 365).to_i
    end

    def shifted_value(value)
      begin
        return (DateTime.parse(value) - offset_days).iso8601[0..9]
      rescue ArgumentError
        return nil
      end
    end

    def date_shift_root_record
      require 'pry'
      binding.pry
      search_model = @magma_model
      record = Magma.instance.db[@magma_model.table_name].where(
        @magma_model.attributes.values.select { |a| a.is_a?(Magma::IdentifierAttribute)} => @record_name
      ).first

      raise DateTimeShiftError, "No record \"#{@record_name}\" found" unless record

      loop do
        break unless search_model # nothing found, is nil
        break if search_model.is_date_shift_root?
        
        search_model = search_model.parent_model
        record = search_model ? record.send(search_model.model_name) : nil
      end

      record
    end
  end
end
