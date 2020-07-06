class Magma
  class CollectionAttribute < Attribute
    include Magma::Link
    def initialize(name, model, opts)
      model.one_to_many(name, class: model.project_model(name), primary_key: :id)
      super
    end

    def query_to_payload(link)
      link = record[name]
      link ? link.map(&:last).sort : nil
    end

    def query_to_tsv(value)
      query_to_payload(value).join(", ")
    end

    def revision_to_loader record, new_ids
      old_links = record.send(name)

      old_ids = old_links.map(&:identifier)

      removed_links = old_ids - new_ids
      added_links = new_ids - old_ids

      existing_links = link_records(added_links).select_map(link_model.identity)
      new_links = added_links - existing_links

      if !new_links.empty?
        now = DateTime.now
        link_model.multi_insert(
          new_links.map do |link|
            {
              link_model.identity => link,
              self_id => record.id,
              created_at: now,
              updated_at: now
            }
          end
        )
      end

      if !existing_links.empty?
        link_records( existing_links ).update( self_id => record.id )
      end
    end

    def revision_to_links(record_name, new_ids)
      yield link_model, new_ids
    end

    def revision_to_payload(record_name, value, user)
      [ @name, value ]
    end

    def missing_column?
      false
    end

    class Validation < Magma::Validation::Attribute::BaseAttributeValidation
      def validate(value, &block)
        unless value.is_a?(Array)
          yield "#{value} is not an Array."
          return
        end
        value.each do |link|
          next unless link
          link_validate(link,&block)
        end
      end
    end

    def after_magma_model_set
      @magma_model.one_to_many(
        attribute_name.to_sym,
        class: @magma_model.project_model(attribute_name),
        primary_key: :id
      )
    end
  end
end
