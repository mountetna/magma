require 'extlib'

class Magma
  def run_command config, cmd = :help, *args
    cmd = cmd.to_sym
    if has_command? cmd
      all_commands[cmd].setup config
      all_commands[cmd].execute *args
    else
      all_commands[:help].execute
    end
  end

  def has_command? cmd
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
    def name
      self.class.name.snake_case.split(/::/).last.to_sym
    end

    def execute
    end

    def self.usage desc
      define_method :usage do
        "  #{"%-30s" % name}#{desc}"
      end
    end

    def setup config
      load_but_dont_validate config
    end

    protected
    def load_but_dont_validate config
      Magma.instance.connect(config[:database])
      Magma.instance.load_models
    end

    def load_and_validate config
      Magma.instance.configure(config)
    end
  end

  class Help < Magma::Command
    usage "List this help"
    def execute
      puts "Commands:"
      Magma.instance.all_commands.each do |name,cmd|
        puts cmd.usage
      end
    end
  end

  class Plan < Magma::Command
    usage "Suggest a migration based on the current model attributes"

    def execute
      migration = Magma::Migration.new
      Magma.instance.magma_models.each do |model|
        migration.suggest_migration model
      end
      puts migration
    end
  end

  class Load < Magma::Command
    usage "Run data loaders on models for current dataset"

    def execute *args
      if args.empty?
        # List available loaders
        exit
      end

      model = Magma.instance.get_model(args[0])
      att = args[1].to_sym
      raise "Could not find attribute #{att} on model #{model}" unless model.attributes[att]
      model.all.each do |record|
        puts record.identifier
        next unless file = record.send(att).file
        record.run_loaders att, file
      end
    end

    def setup config
      load_and_validate config
    end
  end
end
