describe Magma::DateTimeShifter do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  before(:each) do
    project = create(:project, name: 'The Twelve Labors of Hercules')
  
    stub_date_shift_data(project)
  end

  after(:each) do
    set_date_shift_root("monster", false)
  end

  it "throws exception if no salt" do
    expect {
      Magma::DateTimeShifter.new(
        salt: nil,
        record_name: @lion_monster.name,
        magma_model: Labors::Monster
      )
    }.to raise_error(Magma::DateTimeShiftError, ":salt is required")
  end

  it "throws exception if record has no date shift root record" do
    shifter = Magma::DateTimeShifter.new(
      salt: "123",
      record_name: @lion_monster.name,
      magma_model: Labors::Monster
    )
    expect {
      shifter.shifted_value("2000-01-01")
    }.to raise_error(Magma::DateTimeShiftError, "No date shift root record found.")
  end

  it "throws exception if record_name not found" do
    shifter = Magma::DateTimeShifter.new(
      salt: "123",
      record_name: @hydra_monster.name,
      magma_model: Labors::Monster
    )
    expect {
      shifter.shifted_value("2000-01-01")
    }.to raise_error(Magma::DateTimeShiftError, "No record \"#{@hydra_monster.name}\" found.")
  end

  it "date-shifts a given value" do
    set_date_shift_root("monster", true)
    shifter = Magma::DateTimeShifter.new(
      salt: "123",
      record_name: @lion_monster.name,
      magma_model: Labors::Monster
    )
    expect(shifter.shifted_value("2000-01-01")).not_to eq("2000-01-01")
  end

  it "returns nil if value is not in a valid date format" do
    set_date_shift_root("monster", true)
    shifter = Magma::DateTimeShifter.new(
      salt: "123",
      record_name: @lion_monster.name,
      magma_model: Labors::Monster
    )
    expect(shifter.shifted_value("tomorrow")).to eq(nil)
  end

  describe 'date_shift_root_record' do
    let(:shifter) {
      Magma::DateTimeShifter.new(
        salt: "123",
        record_name: @lion_monster.name,
        magma_model: Labors::Monster
      )
    }

    after(:each) do
      set_date_shift_root("monster", false)
    end

    it 'returns self if model is the date_shift_root' do
      set_date_shift_root("monster", true)

      expect(@lion_monster.date_shift_root_record).to eq(@lion_monster)
      expect(@hydra_monster.date_shift_root_record).to eq(@hydra_monster)
    end

    it 'returns right record if an ancestor model is date_shift_root' do
      set_date_shift_root("monster", true)

      expect(@john_arm.date_shift_root_record).to eq(@lion_monster)
      expect(@susan_arm.date_shift_root_record).to eq(@hydra_monster)
    end
    
    it 'returns nil if no ancestor model is date_shift_root' do
      expect(@john_arm.date_shift_root_record).to eq(nil)
      expect(@susan_arm.date_shift_root_record).to eq(nil)
    end
  end
end
