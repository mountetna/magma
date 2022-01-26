require 'date'
require 'logger'
require 'etna/command'

class Magma
  class RetrieveProjectTemplate < Etna::Command
    string_flags << '--file'
    string_flags << '--target-model'

    def execute(project_name, target_model: 'project', file: "#{project_name}_models_#{target_model}_tree.csv")
      unless File.exists?(file)
        puts "File #{file} is being prepared from the #{project_name} project."
        puts "Copying models descending from #{target_model}..."
        prepare_template(file, project_name, target_model)
        puts
        puts "Done!  You can start editing the file #{file} now"
      else
        puts "File #{file} already exists!  Please remove or specify a different file name before running again."
      end
    end

    def workflow
      @workflow ||= Etna::Clients::Magma::AddProjectModelsWorkflow.new(magma_client: magma_client)
    end

    def magma_client
      Etna::Clients::LocalMagmaClient.new
    end

    def prepare_template(file, project_name, target_model)
      tf = Tempfile.new

      begin
        File.open(tf.path, 'wb') { |f| workflow.write_models_template_csv(project_name, target_model, io: f) }
        FileUtils.cp(tf.path, file)
      ensure
        tf.close!
      end
    end

    def setup(config)
      super
      Magma.instance.setup_db
      Magma.instance.load_models
      require_relative './server'
    end
  end

  class LoadProject < Etna::Command
    usage '[project_name, path/to/file.json] # Import attributes into database for given project name from JSON file'

    def execute(project_name, file_name)
      file = File.open(file_name)
      file_data = JSON.parse(file.read, symbolize_names: true)

      file_data[:models].each do |model_name, model_json|
        model_name = model_name.to_s
        template = model_json[:template]

        load_model(project_name, model_name, template)

        template[:attributes].each do |attribute_name, attribute|
          load_attribute(project_name, model_name, attribute)
        end
      end
    end

    def setup(config)
      super
      Magma.instance.setup_db
    end

    private

    def load_model(project_name, model_name, template)
      dictionary_json = if template[:dictionary]
        template[:dictionary][:attributes].merge(
          dictionary_model: template[:dictionary][:dictionary_model]
        )
      else
        nil
      end

      Magma.instance.db[:models].insert(
        project_name: project_name,
        model_name: model_name,
        dictionary: Sequel.pg_json_wrap(dictionary_json),
      )
    end

    def load_attribute(project_name, model_name, attribute)
      row = attribute.
        slice(*options).
        merge(
          project_name: project_name,
          model_name: model_name,
          column_name: attribute[:attribute_name],
          type: attribute[:attribute_type],
          validation: Sequel.pg_json_wrap(attribute[:validation]),
        )

      Magma.instance.db[:attributes].insert(row)
    end

    def options
      require_relative './attribute'
      @options ||= Magma::Attribute.options - [:loader] + [:created_at, :updated_at, :attribute_name]
    end
  end

  class Migrate < Etna::Command
    usage "Run database wide migrations"
    string_flags << '--version'

    def execute(version: nil)
      Sequel.extension(:migration)
      db = Magma.instance.db

      if version
        puts "Migrating to version #{version}, globally"
        Sequel::Migrator.run(db, File.join("db", "migrations"), target: version.to_i)
      else
        puts 'Migrating to latest, globally'
        Sequel::Migrator.run(db, File.join("db", "migrations"))
      end
    end

    def setup(config)
      super
      Magma.instance.setup_db
    end
  end

  class Console < Etna::Command
    usage 'Open a console with a connected magma instance.'

    def execute
      require 'irb'
      ARGV.clear
      IRB.start
    end

    def setup(config)
      super
      Magma.instance.load_models
    end
  end

  class Load < Etna::Command
    usage 'Run data loaders on models for current dataset.'

    def execute(*args)
      loaders = Magma.instance.find_descendents(Magma::Loader)

      if args.empty?
        # List available loaders
        puts 'Available loaders:'
        loaders.each do |loader|
          puts "%30s  %s" % [ loader.loader_name, loader.description ]
        end
        exit
      end

      loader = loaders.find do |l| l.loader_name == args[0] end

      raise "Could not find a loader named #{args[0]}" unless loader

      loader = loader.new
      loader.load(*args[1..-1])
      begin
        loader.dispatch
      rescue Magma::LoadFailed => e
        puts "Load failed with these complaints:"
        puts e.complaints
      end
    end

    def setup(config)
      super
      Magma.instance.load_models
    end
  end

  class Unload < Etna::Command
    usage '<project_name> <model_name> # Dump the dataset of the model into a tsv'

    def execute(project_name, model_name)
      require_relative './payload'
      require_relative './retrieval'
      require_relative './tsv_writer'

      begin
        model = Magma.instance.get_model(project_name, model_name)
        retrieval = Magma::Retrieval.new(model, 'all', 'all', page: 1, page_size: 100_000)
        payload = Magma::Payload.new
        Magma::TSVWriter.new(model, retrieval, payload).write_tsv{ |lines| puts lines }
      rescue Exception => e
        puts "Unload failed:"
        puts e.message
      end
    end

    def setup(config)
      super
      Magma.instance.load_models
      Magma.instance.setup_db
    end
  end

  class MeasureDataRows < Etna::Command
    def setup(config)
      super
      Magma.instance.load_models
      Magma.instance.setup_db
    end

    def execute
      Magma.instance.magma_projects.keys.each do |project_name|
        project = Magma.instance.get_project(project_name)
        project.models.each do |model_name, model|
          tags = {model_name: model_name.to_s, project_name: project_name.to_s}
          Yabeda.magma.data_rows.set(tags, model.count)
        end
      end
    end
  end
end
