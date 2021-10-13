require 'date'
require 'logger'
require 'etna/command'

class Magma
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
    string_flags << '--version'

    def execute(version: nil)
      Sequel.extension(:migration)
      db = Magma.instance.db

      project_path = Magma.instance.config(:project_path)
      project_paths = project_path&.split(/\s+/) || []
      project_paths = project_paths.select { |p| !p.nil? && !p.empty? }

      project_paths.each do |project_dir|
        table = "schema_info_#{project_dir.gsub(/[^\w]+/,'_').sub(/^_/,'').sub(/_$/,'')}"

        unless ::File.exists?(File.join(project_dir, 'migrations'))
          if Magma.instance.environment == :development || Magma.instance.environment == :test
            puts "Project #{project_dir} is listed in your config.yml, but it does not exist in your magma directory.  Ignoring.."
          else
            raise "Project #{project_dir} does not exist in the magma app directory, perhaps it is not checked out."
          end

          next
        end

        if version
          puts "Migrating to version #{version}"
          Sequel::Migrator.run(db, File.join(project_dir, 'migrations'), table: table, target: version.to_i)
        else
          puts 'Migrating to latest'
          Sequel::Migrator.run(db, File.join(project_dir, 'migrations'), table: table)
        end
      end
    end

    def setup(config)
      super
      Magma.instance.setup_db
    end
  end

  class GlobalMigrate < Etna::Command
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

  # When building migrations from scratch this command does not output
  # an order that respects foreign key constraints. i.e. The order in which the
  # migration creates tries to create the tables is out of whack and causes
  # error messages that tables are required but do not exist. Most of the time
  # this is not an issue (because we are only doing slight modifications), but
  # when we do a new migration of an established database errors do arise.
  # Presently we are manually reorgaizing the initial migration (putting the
  # the table creation in the correct order), but we should add logic here so
  # we do not have to in the future.
  class Plan < Etna::Command
    usage '[<project_name>] # Suggest a migration based on the current model attributes.'

    def execute(project_name=nil)
      if project_name
        project = Magma.instance.get_project(project_name)
        raise ArgumentError, "No such project #{project_name}!" unless project
        projects = [ project ]
      else
        projects = Magma.instance.magma_projects.values
      end
      puts <<EOT
Sequel.migration do
  change do
#{projects.map(&:migrations).flatten.join("\n")}
  end
end
EOT
    end

    def setup(config)
      super
      Magma.instance.load_models(false)
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

  class CreateDb < Etna::Command
    usage '<project_name> # Attach an existing project to a magma instance, creating database and schema'

    def execute(project_name)
      @project_name = project_name
      create_db if @no_db

      create_schema unless db_namespace?

      puts "Database is setup. Please run `bin/magma migrate #{@project_name}`."
    end

    def db_namespace?
      Magma.instance.db[ "SELECT 1 FROM pg_namespace WHERE nspname='#{@project_name}'" ].count > 0
    end

    def create_schema
      puts "Creating namespace (schema) #{@project_name} in database #{@db_config[:database]}"

      Magma.instance.db.run "CREATE SCHEMA IF NOT EXISTS #{@project_name}"
    end

    def create_db
      # Create the database only

      puts "Creating database #{@db_config[:database]}"
      %x{ PGPASSWORD=#{@db_config[:password]} createdb -w -U #{@db_config[:user]} #{@db_config[:database]} }

      Magma.instance.setup_db
    end

    def setup(config)
      super
      @db_config = Magma.instance.config(:db)
      begin
        Magma.instance.setup_db
      rescue Sequel::DatabaseConnectionError
        @no_db = true
      end
    end
  end
end
