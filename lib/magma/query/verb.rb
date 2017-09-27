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
        require 'pry'
        binding.pry
        raise ArgumentError, "Verb for #{@predicate} cannot do #{action}"
      end
    end

    def gives?(action)
      instance_variable_defined?("@#{action}")
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
        raise ArgumentError, "Cannot determine child_predicate for #{@predicate}"
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
        raise ArgumentError, "Cannot determine join for #{@predicate}"
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
        raise ArgumentError, "Cannot determine constraint for #{@predicate}"
      end
    end
    def extract(*args, &block)
      @extract = block_given? ? block : args
    end

    def get_extract(*args)
      @predicate.instance_exec(*args, &@extract)
    end
  end
end
