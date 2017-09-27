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
        raise ArgumentError, "Verb for #{@predicate} cannot do #{action}"
      end
    end

    def gives?(action)
      instance_variable_defined?("@#{action}")
    end

    private

    def child(*args, &block)
      @child = block_given? ? block : args
    end

    def get_child
      case @child
      when Symbol
        @predicate.send @child
      when Proc
        @predicate.instance_exec(&@child)
      when Class
        @predicate.send :terminal, @child
      end
    end

    def join(*args, &block)
      @join = block_given? ? block : args
    end

    def constraint(*args, &block)
      @constraint = block_given? ? block : args
    end

    def extract(*args, &block)
      @extract = block_given? ? block : args
    end

    def get_extract(*args)
      @predicate.instance_exec(*args, &@extract)
    end
  end
end
