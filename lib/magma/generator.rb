class Magma
  class Generator 
    def self.description(desc = nil)
      @description ||= desc
    end

    def self.generator_name
      name.snake_case.sub(/_generator$/, '')
    end

    def initialize
      @test = 'this'
    end
  end
end
