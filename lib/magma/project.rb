class Magma
  class Project
    attr_reader :project_name

    def initialize project_dir
      @project_dir = project_dir
      @project_name = project_dir.split('/').last.to_sym

      load_project
    end

    def models
      @models ||= Hash[
        project_container.constants(false).map do |c|
          project_container.const_get(c) 
        end.select do |m| m < Magma::Model end.map do |m|
          [ m.model_name, m ]
        end
      ]
    end

    def migrations
      models.values.map(&:migration).reject(&:empty?)
    end

    private

    def project_container
      @project_container ||= Kernel.const_get(@project_name.to_s.camel_case)
    end

    def load_project
      base_file = project_file('requirements.rb')
      if File.exists?(base_file)
        require base_file 
      else
        require_files('models')
        require_files('loaders')
        require_files('metrics')
      end
    end

    def require_files folder
      Dir.glob(project_file(folder, '**', '*.rb'), &method(:require))
    end

    def project_file *filenames
      File.join(File.dirname(__FILE__), '../..', @project_dir, *filenames)
    end

  end
end
