class TSVLoader < Magma::Loader
  description "Insert or update data from a TSV file"

  def load file, model_name
    @table = CSV.read(file, col_sep: "\t")
    @model = Magma.instance.get_model(model_name)
    @header = @table.shift.map(&:to_sym)

    bad_attributes = @header.reject do |name| @model.has_attribute?(name) end

    raise "Could not find attributes named #{bad_attributes.join(", ")} on #{model}" unless bad_attributes.empty?
  end

  def dispatch
    create_self_records

    dispatch_record_set
  end

  private

  def create_self_records
    now = DateTime.now

    @table.each do |row|
      push_record(
        @model, 
        Hash[@header.zip(row)].merge(
          created_at: now,
          updated_at: now
        )
      )
    end
  end
end
