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

    def is_collection_attribute?(attribute)
      attribute.is_a?(Magma::CollectionAttribute)
    end

    def is_child_attribute?(attribute)
      attribute.is_a?(Magma::ChildAttribute)
    end

    def is_table_attribute?(attribute)
      attribute.is_a?(Magma::TableAttribute)
    end

    def is_foreign_key_parent?(attribute)
      # Based on the attribute class, determines if this is the "foreign key holder",
      #   for a link relationship. If so, return true.
      is_collection_attribute?(attribute) ||
      is_child_attribute?(attribute) ||
      is_table_attribute?(attribute)
    end

    def explicit_child_revision_exists?(revisions, model_name, record_name, attribute_name)
      # Check if the child's parent is being explicitly set by the user
      binding.pry
      !!revisions.dig(model_name.to_sym, record_name.to_sym, attribute_name.to_sym)
    end

    def explicit_parent_revision_exists?(revisions, model_name, record_name, attribute, child_record_name)
      # We need to check if the child record has
      #   been set for ANY record in the same parent_model.

      # NOTE: different check behavior for CollectionAttribute vs. ChildAttribute!
      explicit_revisions_found = 0

      revisions[model_name.to_sym].each do |record_name, record_revisions|
        next unless record_revisions.key?(attribute.attribute_name.to_sym)

        attribute_revision = record_revisions[attribute.attribute_name.to_sym]

        explicit_revisions_found += 1 if is_collection_attribute?(attribute) && attribute_revision.include?(child_record_name)
        explicit_revisions_found += 1 if is_child_attribute?(attribute) && child_record_name == attribute_revision
      end

      explicit_revisions_found > 0
    end

    def explicit_revision_exists?(revisions:, parent_model:, parent_record_name:, child_record_name:, parent_attribute:)
      # Cannot find explicit revisions from @records, because
      #   some of those are calculated! So we have to look for
      #   explicit revisions from the user-supplied revisions hash.
      # Note that because explicit revisions can be either parent -> child
      #   or child -> parent, we need to check both cases.
      explicit_child_revision_exists?(
        revisions,
        parent_attribute.link_model.model_name,
        child_record_name,
        parent_model.model_name) ||
      explicit_parent_revision_exists?(
        revisions,
        parent_model.model_name,
        parent_record_name,
        parent_attribute,
        child_record_name)
    end

    def push_implied_link_revisions(revisions)
      # When updating link or parent attributes from the top-down,
      #   we may not know what the previous relationships were.
      # For example, changing a link child from record A to B,
      #   the explicit revision is LinkModel -> B.
      # But there is also an implied revision, of updating
      #   record A to have a `nil` parent.
      # So we also have to push records for all the
      #   implied link revisions, when the attribute
      #   is a Child or Collection type (i.e. the revision
      #   comes from the parent / link).
      # But, in a multi-revision scenario, we should
      #   only push the implied revisions when those records + attributes
      #   themselves aren't being revised, otherwise we risk
      #   overwriting an explicit revision.

      # We iterate over revisions to see what all has been updated.
      # If there are any ChildAttribute or CollectionAttribute values
      #   that changed, we'll need to investigate further if any implied
      #   revisions exist.
      # Do not do this over @records, because some of those revisions
      #   are calculated and could lead to incorrectly orphaning
      #   currently-attached records.
      revisions.each do |model_name, model_revisions|
        model = Magma.instance.get_model(@project_name, model_name)

        model_revisions.each do |record_name, revision|
          revision.each do |attribute_name, value|
            attribute = model.attributes[attribute_name]

            # Note that we have to treat TableAttributes differently,
            #   because they don't have "record_name" identifiers
            #   that are specified in the revisions ... they use temporary ids
            #   in the revisions and will only return database ids
            #   in a query. Since those don't match, we can't rely on the
            #   query method to find implied links.

            push_implied_link_revision(
              revisions: revisions,
              parent_attribute: attribute,
              parent_model: model,
              parent_record_name: record_name.to_s) if is_collection_attribute?(attribute) || is_child_attribute?(attribute)
          end
        end
      end
    end

    def push_implied_link_revision(revisions:, parent_attribute:, parent_model:, parent_record_name:)
      # Here we fetch all current records that have the model::record_name as the
      #   parent, and then we compare that to new_link_identifiers.
      # For any record that has been removed or un-linked, we call push_record()
      #   with that record, setting its parent to `nil`.
      child_model = parent_attribute.link_model

      question = Magma::Question.new(@project_name, [
        child_model.model_name,
        [parent_model.model_name, '::identifier', '::in', [parent_record_name]],
          '::all', '::identifier'
      ])
      current_record_names = question.answer.map(&:last).flatten

      current_record_names.reject { |record_name|
        explicit_revision_exists?(
          revisions: revisions,
          parent_model: parent_model,
          parent_record_name: parent_record_name,
          child_record_name: record_name,
          parent_attribute: parent_attribute)
       }.each do |record_name|
        push_record(
          child_model, record_name,
          parent_model.model_name.to_sym => nil,
          updated_at: @now)
      end
    end

    def push_links(model, record_name, revision)
      revision.each do |attribute_name, value|
        next unless model.has_attribute?(attribute_name)

        attribute = model.attributes[attribute_name]

        attribute.revision_to_links(record_name, value) do |link_model, link_identifiers|
          # When the explicit revision is from the parent / link -> children, the
          #   new link records need to be single-entry records,
          #   because they are linking from child up to a single
          #   parent.
          # When the explicit revision is from the child -> parent / link,
          #   the new link records need to be Arrays,
          #   because they are linking from parent to a collection
          #   of records.
          link_record_name = is_foreign_key_parent?(attribute) ?
            record_name.to_s :
            [ record_name.to_s ]

          link_identifiers&.each do |link_identifier|
            next if link_identifier.nil?
            push_record(
              link_model, link_identifier,
              model.model_name.to_sym => link_record_name,
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
      return nil unless identifier

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
