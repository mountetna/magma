class Magma
  class Controller < Etna::Controller
    def initialize(request)
      super
      @project_name = @params[:project_name]
    end
  end
end
