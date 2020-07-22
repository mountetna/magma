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
      ensure_identifier(@model, @record_name.to_s).update(
        to_record do |attribute, value|
          attribute.revision_to_payload(@record_name, value, user)
        end
      )
    end

    def to_loader(loader)
      # ensure the identifier
      ensure_identifier(@model, @record_name.to_s, loader).update(
        to_record do |attribute, value|
          attribute.revision_to_loader(@record_name, value)
        end
      )
    end

    def ensure_identifier(model, identifier, loader=nil)
      if loader && model.identity == :id && identifier =~ /^::temp/
        return { temp_id: loader.temp_id(identifier.to_sym) }
      end

      { model.identity => identifier }
    end

    def each_linked_record(loader)
      each_attribute do |attribute, value|
        attribute.revision_to_links(@record_name, value) do |link_model, link_identifiers|
          link_identifiers.each do |link_identifier|
            link_record = ensure_identifier(
              link_model, link_identifier, loader
            ).update(
              :$identifier => link_identifier,
              model.model_name.to_sym => @record_name.to_s,
              created_at: now,
              updated_at: now
            )
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
