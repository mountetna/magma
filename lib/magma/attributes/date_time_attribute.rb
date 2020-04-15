class Magma
  class DateTimeAttribute < Attribute
    def initialize(name, model, opts)
      super(name, model, opts.merge(type: DateTime))
    end
  end
end