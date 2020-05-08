class Magma
  class ParentAttribute < ForeignKeyAttribute
    def initialize(name=nil, model, opts)
      unless name.nil?
        model.many_to_one(name)
        super(name, model, opts)
      end
    end
  end
end
