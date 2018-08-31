class Magma
  class ChildAttribute < Attribute
    include Magma::Link
    def json_for record
      record[@name]
    end

    def update record, link
      link_model.update_or_create(link_model.identity => link) do |obj|
        obj[ self_id ] = record.id
      end
    end
  end
end
