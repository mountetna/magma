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
    class << self
      def description desc=nil
        @description ||= desc
      end

      def loader_name
        name.snake_case.sub(/_loader$/,'')
      end
    end

    attr_reader :validator, :user

    def initialize(user, project_name)
      @user = user
      @project_name = project_name
      @validator = Magma::Validation.new
      @censor = Magma::Censor.new(@user,@project_name)
      @records = {}
      @temp_id_counter = 0
      @attribute_entries = {}
      @identifiers = {}
      @now = Time.now.iso8601
    end

    def push_record(model, record_name, revision)
      records(model)[record_name] ||= RecordEntry.new(model, record_name, self)

      records(model)[record_name] << revision
    end

    def to_payload
      payload = Magma::Payload.new

      @records.each do |model, record_set|
        next if record_set.empty?

        payload.add_model(model)

        payload.add_records(model, record_set.values.map(&:payload_entry))
      end

      return payload.to_hash
    end

    def push_links(model, record_name, revision)
      revision.each do |attribute_name, value|
        next unless model.has_attribute?(attribute_name)

        model.attributes[attribute_name].revision_to_links(record_name, value) do |link_model, link_identifiers|
          link_identifiers.each do |link_identifier|
            push_record(
              link_model, link_identifier,
              model.model_name.to_sym => record_name.to_s,
              created_at: @now,
              updated_at: @now
            )
          end
        end
      end
    end

    # Once we have loaded up all the records we wish to insert/update (upsert)
    # we run this function to kick off the DB insert and update queries.
    def dispatch_record_set
      validate!

      censor_revisions!

      run_attribute_hooks!

      upsert
      
      update_temp_ids

      payload = to_payload

      reset

      return payload
    end

    def reset
      @records = {}
      @validator = Magma::Validation.new
      @censor = Magma::Censor.new(@user,@project_name)
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

    TEMP_ID_MATCH=/^::temp/

    def identifier_id(model, identifier)
      @identifiers[model] ||= model.select_map(
        [model.identity.column_name.to_sym, :id]
      ).map do |identifier, id|
        [ identifier.to_s, id ]
      end.to_h

      @identifiers[model][identifier] ||= temp_id([ model, identifier ])

      @identifiers[model][identifier]
    end

    def real_id(model, identifier)
      id = identifier_id(model, identifier)
      id.is_a?(TempId) ? id.real_id : id
    end

    def identifier_exists?(model, identifier)
      !identifier_id(model, identifier).is_a?(TempId)
    end

    def records(model)
      return @records[model] if @records[model]

      @records[model] = {}

      ensure_link_models(model)

      @records[model]
    end

    private

    def validate!
      complaints = []

      @records.each do |model, record_set|
        next if record_set.empty?
        complaints.concat(record_set.values.map(&:complaints))
      end

      complaints.flatten!

      raise Magma::LoadFailed.new(complaints) unless complaints.empty?
    end

    def censor_revisions!
      complaints = []
      @records.each do |model, record_set|
        reasons = @censor.censored_reasons(model, record_set)

        next if reasons.empty?

        complaints += reasons
      end

      raise Magma::LoadFailed.new(complaints) unless complaints.empty?
    end

    def run_attribute_hooks!
      bulk_load_type = {}
      @records.each do |model, record_set|
        model.attributes.each do |att_name, attribute|
          bulk_load_attribute = {}

          record_set.each do |record_name, record|
            next unless record.has_key?(att_name)
            error = attribute.load_hook(self, record_name, record[att_name], bulk_load_attribute)

            raise Magma::LoadFailed.new([error]) if error
          end

          error = attribute.bulk_load_hook(self, bulk_load_attribute)
          raise Magma::LoadFailed.new([error]) if error

          unless bulk_load_attribute.empty?
            bulk_load_type[ attribute.class ] ||= {}
            bulk_load_type[ attribute.class ][ attribute ] = bulk_load_attribute
          end
        end
      end

      bulk_load_type.each do |attribute_class, bulk_type_attributes|
        error = attribute_class.type_bulk_load_hook(self, @project_name, bulk_type_attributes)
        raise Magma::LoadFailed.new([error]) if error
      end
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
