describe Magma::DateTimeShifter do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  before(:each) do
    project = create(:project, name: "The Twelve Labors of Hercules")

    stub_date_shift_data(project)
  end

  it "throws exception if no salt" do
    expect {
      Magma::DateTimeShifter.new(
        salt: nil,
        date_shift_root_record_name: @lion_monster.name,
      )
    }.to raise_error(Magma::DateTimeShiftError, ":salt is required")

    expect {
      Magma::DateTimeShifter.new(
        salt: "",
        date_shift_root_record_name: @lion_monster.name,
      )
    }.to raise_error(Magma::DateTimeShiftError, ":salt is required")
  end

  it "throws exception if no date shift root record" do
    expect {
      shifter = Magma::DateTimeShifter.new(
        salt: "123",
        date_shift_root_record_name: nil,
      )
    }.to raise_error(Magma::DateTimeShiftError, "date_shift_root_record_name is required")

    expect {
      shifter = Magma::DateTimeShifter.new(
        salt: "123",
        date_shift_root_record_name: "",
      )
    }.to raise_error(Magma::DateTimeShiftError, "date_shift_root_record_name is required")
  end

  it "date-shifts a given value" do
    shifter = Magma::DateTimeShifter.new(
      salt: "123",
      date_shift_root_record_name: @lion_monster.name,
    )
    expect(
      shifter.shifted_value(DateTime.parse("2000-01-01")).iso8601
    ).not_to eq(iso_date_str("2000-01-01"))
  end

  it "throws exception if value is not in a valid date format" do
    shifter = Magma::DateTimeShifter.new(
      salt: "123",
      date_shift_root_record_name: @lion_monster.name,
    )
    expect {
      shifter.shifted_value("tomorrow")
    }.to raise_error(Magma::DateTimeShiftError, "Invalid value to shift: tomorrow")
  end
end
