class Magma
  class MetricsPredicate < Magma::Predicate
    def initialize question, model, alias_name, *query_args
      super(question)
      @model = model
      @alias_name = alias_name
      process_args(query_args)
    end

    verb nil do
      child Hash
    end

    def extract table, identity
      records = Hash[
        @model.where(
          @model.identity.column_name.to_sym => table.map do |row|
            row[identity]
          end
        ).map do |record|
          [ record.identifier, record ]
        end
      ]

      metrics_for( records[ table.first[identity] ] )
    end

    def metrics_for record
      Hash[
        @model.metrics.map do |metric|
          [ metric.metric_name,  metric.new(record).to_hash ]
        end
      ]
    end

    def select
      @arguments.empty? ? [ Sequel[alias_name][@model.identity.column_name].as(column_name) ] : []
    end

    private

    def column_name
      :"#{alias_name}_#{@model.identity.column_name}"
    end
  end
end
