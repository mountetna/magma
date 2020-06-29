class Magma
  class LinkAttribute < ForeignKeyAttribute
    def initialize(name, model, opts)
      model.many_to_one(name, class: model.project_model(opts[:link_model_name] || name))
      super(name, model, opts)
    end
  end
end

