require_relative './loader/temp_id'
require_relative './loader/multi_update'
require_relative './loader/record_entry'

class Magma
  class LoadFailed < Exception
    attr_reader :complaints

    def initialize(complaints)
      @complaints = complaints
    end
  end

  class BaseAttributeEntry
    def initialize(model, attribute, loader)
      @model = model
      @attribute = attribute
      @loader = loader
    end

    def entry value
      nil
    end
  end

  # A generic loader class.
  class Loader
    attr_reader :validator

    def initialize
      @records = {}
      @temp_id_counter = 0
      @validator = Magma::Validation.new
      @attribute_entries = {}
      @identifiers = {}
    end

    def push_record(model, record)
      id = record[:temp_id]&.is_a?(Magma::TempId) ? record[:temp_id] : record[model.identity]
      records(model)[id] ||= RecordEntry.new(model, self)
      records(model)[id] << record
    end

    # Once we have loaded up all the records we wish to insert/update (upsert)
    # we run this function to kick off the DB insert and update queries.
    def dispatch_record_set
      find_complaints
      upsert
      update_temp_ids
      reset
    end

    def reset
      @records = {}
      @validator = Magma::Validation.new
      @attribute_entries = {}
      @identifiers = {}
      GC.start
    end

    # This lets you give an arbitrary object (e.g. a model used in the loader) a
    # temporary id so you can make database associations.
    def temp_id(obj)
      return nil if obj.nil?
      temp_ids[obj] ||= TempId.new(new_temp_id, obj)
    end

    def identifier_id(model, identifier)
      @identifiers[model] ||= Hash[model.select_map([model.identity, :id])]

      @identifiers[model][identifier]
    end

    alias_method :identifier_exists?, :identifier_id

    def attribute_entry(model, att_name, value)
      return [:id, value] if att_name == :id
      model.attributes[att_name].entry(value, self)
    end

    private

    def records(model)
      return @records[model] if @records[model]

      @records[model] = {}

      ensure_link_models(model)

      @records[model]
    end

    def validate(model, record)
      @validator.validate(model,record) do |error|
        yield error
      end
    end

    def find_complaints
      complaints = []

      @records.each do |model, record_set|
        next if record_set.empty?
        complaints.concat(record_set.values.map(&:complaints))
      end

      complaints.flatten!
      raise Magma::LoadFailed.new(complaints) unless complaints.empty?
    end

    # This 'upsert' function will look at the records and either insert or
    # update them as necessary.
    def upsert
      # Loop the records separate them into an insert group and an update group.
      # @records is separated out by model.
      @records.each do |model, record_set|
        # Skip if the record_set for this model is empty.
        next if record_set.empty?

        # Our insert and update record groupings.
        insert_records = record_set.values.select(&:valid_new_entry?)
        update_records = record_set.values.select(&:valid_update_entry?)

        # Run the record insertion.
        multi_insert(model, insert_records)

        # Run the record updates.
        multi_update(model, update_records)

      end
    end

    def multi_insert(model, insert_records)
      by_attribute_key(insert_records) do |records|
        insert_ids = model.multi_insert(
          records.map(&:insert_entry),
          return: :primary_key
        )

        if insert_ids
          records.zip(insert_ids).each do |record, real_id|
            record.real_id = real_id
          end
        end
      end
    end

    def multi_update(model, update_records)
      by_attribute_key(update_records) do |records|

        MultiUpdate.new(model, records.map(&:update_entry), :id, :id).update
      end
    end

    def by_attribute_key(all_records)
      all_records.group_by(&:attribute_key).each do |_, records|
        yield records
      end
    end

    def update_temp_ids
      @records.each do |model, record_set|
        next if record_set.empty?
        temp_records = record_set.values.select(&:valid_temp_update?)

        MultiUpdate.new(model, temp_records.map(&:temp_entry), :real_id, :id).update
      end
    end

    def temp_ids
      @temp_ids ||= {}
    end

    def new_temp_id
      @temp_id_counter += 1
    end

    def ensure_link_models(model)
      model.attributes.each do |att_name, att|
        records(att.link_model) if att.is_a?(Magma::Link)
      end
    end
  end
end

require_relative './loader/tsv'
