class Magma
  class CollectionAttribute < Attribute
    include Magma::Link
    def initialize(opts = {})
      super
      set_one_to_many if @magma_model
    end

    def magma_model=(new_magma_model)
      super
      set_one_to_many
    end
    
    def json_for record
      link = record[name]
      link ? link.map(&:last).sort : nil
    end

    def txt_for record
      json_for(record).join(", ")
    end

    def update_record record, new_ids
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

      if !removed_links.empty?
        link_records( removed_links ).update( self_id => nil )
      end

      return new_ids.map do |id| [id] end
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

    def set_one_to_many
      @magma_model.one_to_many(
        attribute_name.to_sym,
        class: @magma_model.project_model(attribute_name),
        primary_key: :id
      )
    end
  end
end
