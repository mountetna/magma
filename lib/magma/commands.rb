require 'extlib'
require 'date'
require 'logger'

class Magma
  class Help < Etna::Command
    usage 'List this help'

    def execute
      puts 'Commands:'
      Magma.instance.commands.each do |name,cmd|
        puts cmd.usage
      end
    end
  end

  class Migrate < Etna::Command
    usage 'Run migrations for the current environment.'

    def execute(version=nil)
      Sequel.extension(:migration)
      db = Magma.instance.db

      Magma.instance.config(:project_path).split(/\s+/).each do |project_dir|
        table = "schema_info_#{project_dir.gsub(/[^\w]+/,'_').sub(/^_/,'').sub(/_$/,'')}"
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
    usage 'Suggest a migration based on the current model attributes.'

    def execute
      puts <<EOT
Sequel.migration do
  change do
    #{Magma.instance.magma_projects.values.map(&:migrations).flatten.join("\n")}
  end
end
EOT
    end

    def setup(config, *args)

      # This line allows us to set the project path of the migration plan. That
      # way we are able to create a migration for a single project that may not
      # yet be listed in the config.yml. The default will use the directories
      # listed in the config.yml file.
      env = (ENV['MAGMA_ENV'] || :development).to_sym
      config[env][:project_path] = args[0] if args[0]

      Magma.instance.configure(config)
      Magma.instance.load_projects(false)
    end
  end

  class Timestamp < Etna::Command
    usage 'Generate a current timestamp (for use with \'Magma plan\').'

    def execute
      puts DateTime.now.strftime('%Y%m%d%H%M%S')
    end

    def setup(config)
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
      Magma.instance.load_projects
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

    def setup(config, *args)
      env = (ENV['MAGMA_ENV'] || :development).to_sym
      Magma.instance.configure(config)
      Magma.instance.load_projects(false)
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
        retrieval = Magma::Retrieval.new(model, nil, model.attributes.values, nil, 1, 100_000)
        payload = Magma::Payload.new
        Magma::TSVWriter.new(model, retrieval, payload).write_tsv{ |lines| puts lines }
      rescue Exception => e
        puts "Unload failed:"
        puts e.message
      end
    end

    def setup(config)
      super
      Magma.instance.load_projects
      Magma.instance.setup_db
    end
  end

  # This will create a new project folder with the starting migrations and the
  # appropriate db schema's
  class Create < Etna::Command
    usage "Create a new project with initial schema and folders.
      *args - arg[0]: project_name\n\n"

    def execute(project_name)

      # Check that we have a project name.
      unless project_name
        raise ArgumentError.new('Project name must not be nil.')
      end

      # Check that the project/schema does not yet exisit.
      query = "SELECT * from pg_catalog.pg_namespace where "\
"nspname='#{project_name}'"

      if Magma.instance.db.fetch(query).all.length > 0
        raise ArgumentError.new('Project name already exists in the DB.')
      end

      # Check that the project folder does not exist.
      if File.directory?("#{Dir.pwd}/projects/#{project_name}")
        raise ArgumentError.new('A project folder already exists.')
      end

      # Create the schema in the DB.
      Magma.instance.db.create_schema(project_name.to_sym)

      # Create the project folders.
      base_dir = "#{Dir.pwd}/projects/"
      Dir.mkdir "#{base_dir}#{project_name}"
      Dir.mkdir "#{base_dir}#{project_name}/models"
      Dir.mkdir "#{base_dir}#{project_name}/migrations"

      # Set up the variables required by the templates.
      template_binding = binding
      template_binding.local_variable_set(:project_name, project_name)

      # Create the base model for the project.
      project_model_path = "#{base_dir}example/models/template_project.erb"
      project_model = ERB.new(File.read(project_model_path))
      project_model_file = project_model.result(template_binding)

      # Write the project model file out to disk.
      file_name = File.join(base_dir, project_name.to_s, 'models/project.rb')
      File.open(file_name, 'w') {|f| f.write(project_model_file)}

      # Create the base requirement file for the project.
      req_path = "#{base_dir}example/template_requirements.erb"
      req_file = ERB.new(File.read(req_path)).result()

      # Write the requirements file out to disk.
      file_name = File.join(base_dir, project_name.to_s, '/requirements.rb')
      File.open(file_name, 'w') {|f| f.write(req_file)}

      # Create the base migration for the project
      migration_path = "#{base_dir}example/migrations/template_migration.erb"
      migration = ERB.new(File.read(migration_path))
      migration_file = migration.result(template_binding)

      file_name = File.join(
        base_dir,
        project_name.to_s,
        'migrations/001_start.rb'
      )
      File.open(file_name, 'w') {|f| f.write(migration_file)}

      puts "You can now run the command 'bin/magma migrate #{project_name}' "\
"for your new project.\n"

    end

    def setup(config, *args)
      Magma.instance.configure(config)
      Magma.instance.setup_db
    end
  end
end
