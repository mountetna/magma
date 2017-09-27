class Magma
  class MetricsPredicate < Magma::Predicate
    def initialize model, alias_name, *query_args
      @model = model
      @alias_name = alias_name
      @query_args = query_args
      @child_predicate = get_child
    end

    def extract table, identity
      records = Hash[
        @model.where(
          @model.identity => table.map do |row|
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
      @argument.nil? ? [ Sequel[alias_name][@model.identity].as(column_name) ] : []
    end

    private

    def get_child
      terminal(Hash)
    end

    def column_name
      :"#{alias_name}_#{@model.identity}"
    end
  end
end
