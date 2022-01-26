class Magma
  class Project
    class AttributeLoadError < StandardError
      def initialize(project_name, model_name, attributes)
        attribute_names = attributes.
          map { |attribute| attribute[:attribute_name] }.
          join(", ")

        project_model = "#{project_name.to_s.camel_case}::#{model_name.to_s.camel_case}"

        msg = "Tried to load attributes (#{attribute_names}) from the database on #{project_model} but #{project_model} doesn't exist"

        super(msg)
      end
    end

    attr_reader :project_name

    def initialize(options = {})
      if options[:project_name]
        @project_name = options[:project_name]
      else
        raise ArgumentError, ":project_name required"
      end

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
        att.is_a?(Magma::Link) && att.link_model.parent_model_name == model.model_name
      end.map(&:link_model)
      link_models + link_models.map{|m| ordered_models(m)}.flatten
    end

    def migrations
      ([ models[:project] ] + ordered_models(models[:project])).map(&:migration).reject(&:empty?)
    end

    def load_model(model_data)
      model_class = Class.new(Magma::Model) do
        set_schema(
          model_data[:project_name].to_sym,
          model_data[:model_name].pluralize.to_sym
        )

        dictionary(model_data[:dictionary].symbolize_keys) if model_data[:dictionary]
      end

      project_container.const_set(model_data[:model_name].camelize, model_class)
    end

    private

    def project_container
      @project_container ||=
        Kernel.const_defined?(@project_name.to_s.camel_case) ? Kernel.const_get(@project_name.to_s.camel_case) :
        Object.const_set(@project_name.to_s.camel_case, Module.new)
    end

    def load_project
      load_models
      load_model_attributes
    end

    def load_models
      Magma.instance.db[:models].where(project_name: @project_name.to_s).
        reject { |model| project_container.const_defined?(model[:model_name].camelize) }.
        each { |model| load_model(model) }
    end

    def load_model_attributes
      model_attributes = Magma::Attribute.
        where(project_name: @project_name.to_s).
        to_a.
        group_by { |attribute| attribute.model_name.to_sym }

      model_attributes.each do |model_name, attributes|
        model = models[model_name]
        raise AttributeLoadError.new(@project_name, model_name, attributes) unless model
        model.load_attributes(attributes)
      end
    end
  end
end
