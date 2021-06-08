class Magma
  class Controller < Etna::Controller
    def initialize(request, action=nil)
      super
      @project_name = @params[:project_name]
    end

    def handle_error(e)
      case e
      when NameError
        if e.message.match(/Could not find Magma::Model/)
          return failure(404, error: 'That project or model does not exist.')
        end
      end

      super
    end
  end
end
