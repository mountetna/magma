require_relative "./date_shift_cache"

class Magma
  class RecordHierarchyCache
    def initialize(records)
      @parent_record_name_cache = {}
      @all_model_records = {}
      @all_parent_identifiers = {}
      @path_to_root = {}
      @record_entry_disconnected_cache = {}
      @record_entry_disconnected_by_parent_cache = {}

      @records = records

      @date_shift_cache = Magma::DateShiftCache.new
    end

    # This requires access to both the set of @records from the loader as well as the database.
    def path_to_date_shift_root(model, record_name)
      @path_to_root[model] ||= {}

      return @path_to_root[model][record_name] unless @path_to_root[model][record_name].nil?

      # Check if there is some path to the date-shift-root model, across @records and
      #   the database.
      queue = @date_shift_cache.model_path_to_date_shift_root(model).clone
      has_path = !queue.empty?

      # First model off the queue matches the record_name.
      current_record_name = record_name
      path_to_root = []

      until queue.empty? || !has_path
        model_to_check = queue.shift

        path_to_root << current_record_name

        # If the model is the date-shift-root and we have a record-name for it,
        #   then a path must exist or will be created.
        next if @date_shift_cache.is_date_shift_root?(model_to_check) && !current_record_name.nil?

        # If the user disconnects the record before we've found the date-shift-root
        #   model, then they've broken the path.
        begin
          has_path = false
          next
        end if user_disconnected_record(model_to_check, current_record_name)

        # If parent exists in the @records, and will be created
        parent_record_name = parent_record_name_from_records(model_to_check, current_record_name)

        # If parent not found in @records AND there is not an explicit "disconnect" action,
        #   check the database for the EXISTING record and find its parent.
        # If no existing record (current_record_name is a new record_entry), this should return nil and there is no path
        parent_record_name = parent_record_name_from_db(model_to_check, current_record_name) if parent_record_name.nil?

        begin
          current_record_name = parent_record_name
          next
        end unless parent_record_name.nil?

        # If no parents have been found, the path doesn't exist or is broken
        has_path = false
      end

      path = has_path ? path_to_root : []

      @path_to_root[model][record_name] = path

      path
    end

    private

    def user_disconnected_record(model, record_name)
      record_entry_explicitly_disconnected?(model, record_name) && !@date_shift_cache.is_date_shift_root?(model)
    end

    def record_entry_explicitly_disconnected?(model, record_name)
      @record_entry_disconnected_cache[model] ||= {}

      return @record_entry_disconnected_cache[model][record_name] unless @record_entry_disconnected_cache[model][record_name].nil?

      entry = record_entry_from_records(model, record_name)

      explicitly_disconnected = false

      explicitly_disconnected = (entry.explicitly_disconnected_from_parent?) ||
                                (!entry.explicitly_disconnected_from_parent? &&
                                 record_entry_explicitly_disconnected_by_parent(entry, model, record_name)) unless entry.nil?

      @record_entry_disconnected_cache[model][record_name] = explicitly_disconnected

      explicitly_disconnected
    end

    def record_entry_from_records(model, record_name)
      return @records[model][record_name] if @records[model][record_name]

      nil
    end

    def record_entry_explicitly_disconnected_by_parent(record_entry, model, record_name)
      return false unless !record_entry.includes_parent_record?

      @record_entry_disconnected_by_parent_cache[model] ||= {}

      return @record_entry_disconnected_by_parent_cache[model][record_name] unless @record_entry_disconnected_by_parent_cache[model][record_name].nil?

      explicitly_disconnected = false

      parent_record_name = parent_record_name_from_db(model, record_name)
      parent_entry = record_entry_from_records(model.parent_model, parent_record_name)

      explicitly_disconnected = !parent_entry[model]&.include?(record_name) if parent_entry

      @record_entry_disconnected_by_parent_cache[model][record_name] = explicitly_disconnected

      explicitly_disconnected
    end

    def parent_record_name_from_records(model, record_name)
      record_entry_from_records(model, record_name)&.parent_record_name
    end

    def db_records_for_model_by_identifier(model)
      @all_model_records[model] ||= model.select_map(
        [model.column_name(attribute_type: Magma::IdentifierAttribute),
         model.column_name(attribute_type: Magma::ParentAttribute)]
      ).map do |identifier, parent_id|
        [identifier.to_s, parent_id]
      end.to_h
    end

    def db_record_identifiers_for_model_by_row_id(model)
      @all_parent_identifiers[model] ||= model.select_map(
        [:id,
         model.column_name(attribute_type: Magma::IdentifierAttribute)]
      ).to_h
    end

    def parent_record_in_db(parent_model, parent_record_id)
      parent_record_id && db_record_identifiers_for_model_by_row_id(parent_model).key?(parent_record_id)
    end

    def parent_record_name_from_db(model, record_name)
      @parent_record_name_cache[model] ||= {}

      return @parent_record_name_cache[model][record_name] unless @parent_record_name_cache[model][record_name].nil?

      parent_record_id = db_records_for_model_by_identifier(model)[record_name]

      @parent_record_name_cache[model][record_name] = db_record_identifiers_for_model_by_row_id(model.parent_model)[parent_record_id] if parent_record_in_db(model.parent_model, parent_record_id)

      @parent_record_name_cache[model][record_name]
    end
  end
end
