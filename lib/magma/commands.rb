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
      Magma.instance.configure config
      Magma.instance.load_models false
    end

    def load_and_validate config
      Magma.instance.configure config
      Magma.instance.load_models true
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
      puts <<EOT
Sequel.migration do
  change do
#{Magma.instance.magma_models.map(&:migration).reject(&:empty?).join("\n")}
  end
end
EOT
    end
  end

  class Console < Magma::Command
    usage "Open a console with a connected magma instance"

    def execute
      require 'irb'
      ARGV.clear
      IRB.start
    end

    def setup config
      load_and_validate config
    end
  end

  class Load < Magma::Command
    usage "Run data loaders on models for current dataset"

    def execute *args
      loaders = Magma.instance.find_descendents(Magma::Loader)

      if args.empty?
        # List available loaders
        puts "Available loaders:"
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

    def setup config
      load_and_validate config
    end
  end
end
