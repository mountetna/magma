class Magma
  class Migration
    def initialize
      @changes = []
    end

    def change key, lines
      @changes.push [ key, lines ]
    end

    def to_s
      <<EOT
Sequel.migration do
  change do
#{changes}
  end
end
EOT
    end

    private
    SPC='  '
    def changes
      @changes.map do |key,lines|
        str = SPC*2 + key + ' do' + "\n"
        lines.each do |line|
          str += SPC*3 + line + "\n"
        end
        str += SPC*2 + 'end' + "\n"
        str
      end.join('')
    end
  end
end
