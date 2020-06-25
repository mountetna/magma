class Magma
  class Revision
    attr_reader :model, :record_name
    def initialize(model, record_name, revision)
      @model = model
      @record_name = record_name
      @revision = revision
    end

    def [](k)
      @revision[k]
    end

    def attribute_names
      @revision.keys
    end

    def to_payload(user)
      to_record do |attribute, value|
        attribute.revision_to_payload(@record_name, value, user)
      end
    end

    def to_loader
      to_record do |attribute, value|
        attribute.revision_to_loader(@record_name, value)
      end
    end

    def each_linked_record
      each_attribute do |attribute, value|
        attribute.revision_to_links(record_name, value) do |link_model, link_identifiers|
          link_identifiers.each do |link_identifier|
            link_record = {
              link_model.identity => link_identifier,
              model.model_name.to_sym => record_name.to_s,
              created_at: now,
              updated_at: now
            }
            yield link_model, link_record
          end
        end
      end
    end

    private

    def now
      @now ||= DateTime.now
    end

    def to_record(&block)
      {
        # ensure the identifier
        @model.identity => @record_name.to_s,

        # back up the original identifier
        :$identifier => @record_name.to_s
      }.update(
        each_attribute(&block).compact.to_h
      )
    end

    def each_attribute
      @revision.map do |attribute_name, value|
        next unless @model.has_attribute?(attribute_name)
        yield @model.attributes[attribute_name], value
      end
    end
  end
end
