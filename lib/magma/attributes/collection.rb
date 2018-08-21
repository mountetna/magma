class Magma
  class CollectionAttribute < Attribute
    include Magma::Link
    def schema_ok?
      true
    end

    def schema_unchanged?
      true
    end

    def needs_column?
      nil
    end

    def tab_column?
      nil
    end

    def eager
      @name
    end

    def json_for(record)
      link = record[@name]
      link ? link.map(&:last).sort : nil
    end

    def txt_for(record)
      json_for(record).join(', ')
    end

    def update(record, new_ids)
      old_links = record.send(@name)

      old_ids = old_links.map(&:identifier)

      removed_links = old_ids - new_ids
      added_links = new_ids - old_ids

      existing_links = link_records(added_links).select_map(link_model.identity)
      new_links = added_links - existing_links

      if !new_links.empty?
        link_model.multi_insert(
          new_links.map do |link|
            {link_model.identity => link, self_id => record.id}
          end
        )
      end

      if !existing_links.empty?
        link_records(existing_links).update(self_id=> record.id)
      end

      if !removed_links.empty?
        link_records(removed_links).update(self_id=> nil)
      end
    end

    class Validator < Magma::AttributeValidator
      def validate(values)
        unless values.is_a?(Array)
          yield "#{values} is not an Array."
          return
        end

        # For each sub value in this collection we re-run the validations with
        # the default linked model, identity and value.
        values.each do |link|
          next unless link
          args = [@attribute.link_model, @attribute.link_model.identity, link]
          @validator.validate(*args) do |error|
            yield error
          end
        end
      end
    end
  end
end
