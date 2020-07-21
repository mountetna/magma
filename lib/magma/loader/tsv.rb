class TSVLoader < Magma::Loader
  def load file, project_name, model_name
    @table = CSV.read(file, col_sep: "\t")
    @model = Magma.instance.get_model(project_name, model_name)
    @header = @table.shift.map(&:to_sym)

    bad_attributes = @header.reject do |name| @model.has_attribute?(name) end

    raise "Could not find attributes named #{bad_attributes.join(", ")} on #{model}" unless bad_attributes.empty?
  end

  def dispatch
    inserts = 0
    @insert_size = 100_000
    until @table.empty?
      puts "#{DateTime.now} Inserting #{inserts * @insert_size + 1} to #{(inserts+1) * @insert_size}"
      create_self_records

      puts "#{DateTime.now} Dispatching..."
      dispatch_record_set
      inserts += 1
    end
  end

  private

  def create_self_records
    now = DateTime.now

    rows = @table.shift(@insert_size)

    rows.each do |row|
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
