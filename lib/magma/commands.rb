require 'extlib'
require 'date'
require 'logger'

class Magma
  def run_command(config, cmd = :help, *args)
    self.logger = Logger.new(STDOUT)
    cmd = cmd.to_sym
    if has_command?(cmd)
      all_commands[cmd].setup(config)
      all_commands[cmd].execute(*args)
    else
      all_commands[:help].execute
    end
  end

  def has_command?(cmd)
    all_commands[cmd]
  end

  def all_commands
    @all_commands ||= Hash[
      find_descendents(Magma::Command).map do |c|
        cmd = c.new
        [ cmd.name, cmd ]
      end
    ]
  end

  class Command
    class << self
      def usage(desc)
        define_method :usage do
          "  #{"%-30s" % name}#{desc}"
        end
      end
    end

    def name
      self.class.name.snake_case.split(/::/).last.to_sym
    end

    # To be overridden during inheritance.
    def execute
    end

    # To be overridden during inheritance.
    def setup(config)
      load_but_dont_check_tables(config)
    end

    protected

    def load_but_dont_check_tables(config)
      Magma.instance.configure(config)
      Magma.instance.load_projects(false)
    end

    def load_and_check_tables(config)
      Magma.instance.configure(config)
      Magma.instance.load_projects(true)
    end
  end

  class Help < Magma::Command
    usage 'List this help'

    def execute
      puts 'Commands:'
      Magma.instance.all_commands.each do |name,cmd|
        puts cmd.usage
      end
    end
  end

  class Migrate < Magma::Command
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
      Magma.instance.configure(config)
      Magma.instance.connect(Magma.instance.config(:db))
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
  class Plan < Magma::Command
    usage 'Suggest a migration based on the current model attributes.'

    def execute
      puts <<EOT
Sequel.migration do
  change do
#{Magma.instance.magma_models.map(&:migration).reject(&:empty?).join("\n")}
  end
end
EOT
    end
  end

  class Timestamp < Magma::Command
    usage 'Generate a current timestamp (for use with \'Magma plan\').'

    def execute
      puts DateTime.now.strftime('%Y%m%d%H%M%S')
    end

    def setup(config)
    end
  end

  class Console < Magma::Command
    usage 'Open a console with a connected magma instance.'

    def execute
      require 'irb'
      ARGV.clear
      IRB.start
    end

    def setup(config)
      load_and_check_tables(config)
    end
  end

  class Load < Magma::Command
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
      load_and_check_tables(config)
    end
  end
end
