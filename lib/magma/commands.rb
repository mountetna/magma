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
    usage '[<version_number>] # Run migrations for the current environment.'
    
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

  class GlobalMigrate < Etna::Command
    usage "Run database wide migrations"

    def execute(version = nil)
      Sequel.extension(:migration)
      db = Magma.instance.db

      if version
        puts "Migrating to version #{version}"
        Sequel::Migrator.run(db, File.join("db", "migrations"), target: version.to_i)
      else
        puts 'Migrating to latest'
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

      Magma.instance.db.run "CREATE SCHEMA #{@project_name}"
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
