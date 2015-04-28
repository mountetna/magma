class Magma
  class Migration
    def initialize
    end

    def change text
      @change = text
    end

    def to_s
      <<EOT
Sequel.migration do
  change do
    #{@change}
  end
end
EOT
    end
  end
end
