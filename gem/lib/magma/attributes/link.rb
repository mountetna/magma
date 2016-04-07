class Magma
  module Link
    def link_model
      Magma.instance.get_model(@name)
    end

    def foreign_id
      :"#{@name}_id"
    end

    def self_id
      :"#{@model.name.snake_case}_id"
    end

    def link_record identifier
      link_model[ link_model.identity => identifier ]
    end

    def link_records identifiers
      link_model.where( link_model.identity => identifiers )
    end

    def link_identity
      link_model.attributes[link_model.identity]
    end
  end
end
