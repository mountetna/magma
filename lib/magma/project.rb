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
        end.select do |m|
          m.is_a?(Class) && m < Magma::Model
        end.map do |m|
          [ m.model_name, m ]
        end
      ]
    end

    def ordered_models(model)
      link_models = model.attributes.values.select do |att|
        att.is_a?(Magma::Link) && att.link_model_name.parent_model_name == model.model_name
      end.map(&:link_model_name)
      link_models + link_models.map{|m| ordered_models(m)}.flatten
    end

    def migrations
      ([ models[:project] ] + ordered_models(models[:project])).map(&:migration).reject(&:empty?)
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

      load_model_attributes
    end

    def load_model_attributes
      model_attributes = Magma.instance.db[:attributes].
        where(project_name: @project_name.to_s).
        to_a.
        group_by { |attribute| attribute[:model_name].to_sym }

      model_attributes.each do |model_name, attributes|
        model = models[model_name]
        model.load_attributes(attributes)
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
