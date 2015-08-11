class Magma
  module Link
    def link_model_name
      @link_model_name || @name
    end

    def link_model
      Magma.instance.get_model(link_model_name)
    end
  end
end
