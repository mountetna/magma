class Magma
  # this class helps define new actions (verbs) handled by a particular Predicate
  class Verb
    def initialize(predicate, block)
      @predicate = predicate
      @block = block
      instance_eval(&block)
    end

    def do(action, *args)
      if respond_to?(:"get_#{action}", true)
        send :"get_#{action}", *args
      else
        raise "Verb for #{@predicate} cannot do #{action}"
      end
    end

    def gives?(action)
      instance_variable_defined?("@#{action}")
    end

    def return_type
      if @child.is_a?(Class)
        @child.name
      else
        nil
      end
    end

    private

    def child(arg=nil, &block)
      @child = block_given? ? block : arg
    end

    def get_child
      case @child
      when Symbol
        @predicate.send @child
      when Proc
        @predicate.instance_exec(&@child)
      when Class
        @predicate.send :terminal, @child
      else
        raise "Cannot determine child_predicate for #{@predicate}"
      end
    end

    def join(arg=nil, &block)
      @join = block_given? ? block : arg
    end

    def get_join
      case @join
      when Symbol
        @predicate.send @join
      when Proc
        @predicate.instance_exec(&@join)
      else
        raise "Cannot determine join for #{@predicate}"
      end
    end

    def constraint(*args, &block)
      @constraint = block_given? ? block : args
    end

    def get_constraint
      case @constraint
      when Symbol
        @predicate.send @constraint
      when Proc
        @predicate.instance_exec(&@constraint)
      else
        raise "Cannot determine constraint for #{@predicate}"
      end
    end

    def extract(*args, &block)
      @extract = block_given? ? block : args
    end

    def get_extract(*args)
      @predicate.instance_exec(*args, &@extract)
    end

    def format(*args, &block)
      @format = block_given? ? block : args
    end

    def validate(&block)
      @validate = block_given? ? block : nil
    end

    def get_validate(arguments)
      if @validate && !@validate.call(arguments)
        raise QuestionError, "Invalid verb arguments #{arguments.join(', ')}"
      end
    end

    def get_format(*args)
      @predicate.instance_exec(*args, &@format)
    end

    def subquery(*args, &block)
      @subquery = block_given? ? block : args
    end

    def get_subquery(*args)
      @predicate.instance_exec(*args, &@subquery)
    end

    def subquery_config(*args, &block)
      @subquery_config = block_given? ? block : args.first
    end

    def get_subquery_config(*args)
      @subquery_config
    end

    def select_columns(*args, &block)
      @select_columns = block_given? ? block : args
    end

    def get_select_columns
      case @select_columns
      when Symbol
        @predicate.send @select_columns
      when Proc
        @predicate.instance_exec(&@select_columns)
      else
        raise "Cannot determine select_columns for #{@predicate}"
      end
    end
  end
end
