class Magma
  class DateShiftCache
    # Cache model state and paths to date_shift_root
    def initialize
      @is_date_shift_root = {}
      @paths_to_date_shift_root = {}
    end

    def is_date_shift_root?(model)
      # Do not use ||= because model.is_date_shift_root? is a boolean, and
      #   falsy values re-trigger assignment with ||=
      return @is_date_shift_root[model] if @is_date_shift_root.key?(model)

      @is_date_shift_root[model] = model.is_date_shift_root?
    end

    def model_path_to_date_shift_root(model)
      @paths_to_date_shift_root[model] ||= model.path_to_date_shift_root
    end
  end
end
