class Magma
  class DateTimeShiftError < StandardError
  end

  class DateTimeShifter
    def initialize(salt:, date_shift_root_record_name:)
      raise DateTimeShiftError, ":salt is required" if salt.nil? || salt.empty?
      raise DateTimeShiftError, "date_shift_root_record_name is required" if date_shift_root_record_name.nil? || date_shift_root_record_name.empty?

      @salt = salt
      @date_shift_root_record_name = date_shift_root_record_name
    end

    def offset_id
      @date_shift_root_record_name
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
      raise DateTimeShiftError, "Invalid value to shift: #{value}" unless value.is_a?(DateTime)
      begin
        return value - offset_days
      rescue ArgumentError
        return nil
      end
    end
  end
end
