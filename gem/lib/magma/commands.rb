require 'extlib'

class Magma
  def run_command cmd = :help, *args
    cmd = cmd.to_sym
    if has_command? cmd
      all_commands[cmd].execute *args
    else
      all_commands[:help].execute
    end
  end

  def has_command? cmd
    all_commands[cmd]
  end

  def all_commands
    @all_commands ||= find_descendents(Magma::Command).map do |c|
      cmd = c.new
      { cmd.name => cmd }
    end.reduce :merge
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
      Magma.instance.magma_models.each do |model|
        model.suggest_migration
      end
    end
  end
end
