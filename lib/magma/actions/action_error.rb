class Magma
  class ActionError
    attr_reader :message, :source, :reason

    def initialize(message:, source:, reason: nil)
      @message = message  
      @source = source
      @reason = reason
    end

    def to_h
      {message: message, source: source, reason: reason}
    end
  end
end
