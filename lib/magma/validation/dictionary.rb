class Magma
  class Validation
    class Dictionary < Magma::Validation::Model
      def initialize model, validation
        super
        @dictionary = @model.dictionary
      end

      def entries
        @entries ||= @dictionary.entries
      end

      def validate(document)
        return unless @dictionary

        entry = entries.find do |entry|
          @dictionary.matches_entry?(entry, document)
        end

        unless entry
          yield "No matching entries for dictionary #{@dictionary}"
        end
      end
    end
  end
end
