require_relative '../lib/magma'
require 'yaml'

describe Magma::Model do
  describe '.has_attribute?' do
    it 'determines whether an attribute exists' do
      expect(Labors::Monster.has_attribute?(:species)).to be_truthy
      expect(Labors::Monster.has_attribute?(:nonexistent_attribute_name)).to be_falsy
    end
  end

  describe '.json_template' do
    it 'returns a json template describing the model' do
      template = Labors::Monster.json_template

      expect(template.values_at(:name, :identifier, :parent)).to eq([:monster, :name, :labor])
      expect(template[:attributes].keys).to include(:created_at, :updated_at, :labor, :name, :species)
    end
  end

  describe 'date_shift_root' do
    let(:action) { Magma::SetDateShiftRootAction.new("labors", action_params) }
    let(:unset_action) { Magma::SetDateShiftRootAction.new("labors", unset_action_params) }

    let(:action_params) do
      {
        action_name: "set_date_shift_root",
        model_name: "monster",
        date_shift_root: true,
      }
    end

    let(:unset_action_params) do
      {
        action_name: "set_date_shift_root",
        model_name: "monster",
        date_shift_root: false,
      }
    end

    def stub_data
      project = create(:project, name: 'The Twelve Labors of Hercules')
      
      hydra = create(:labor, :hydra, project: project)
      lion = create(:labor, :lion, project: project)
      
      @lion_monster = create(:monster, :lion, labor: lion)
      @hydra_monster = create(:monster, :hydra, labor: hydra)

      john_doe = create(:victim, name: 'John Doe', monster: @lion_monster, country: 'Italy')
      jane_doe = create(:victim, name: 'Jane Doe', monster: @lion_monster, country: 'Greece')

      susan_doe = create(:victim, name: 'Susan Doe', monster: @hydra_monster, country: 'Italy')
      shawn_doe = create(:victim, name: 'Shawn Doe', monster: @hydra_monster, country: 'Greece')

      @john_arm = create(:wound, victim: john_doe, location: 'Arm', severity: 5)
      create(:wound, victim: john_doe, location: 'Leg', severity: 1)
      create(:wound, victim: jane_doe, location: 'Arm', severity: 2)
      create(:wound, victim: jane_doe, location: 'Leg', severity: 4)
      @susan_arm = create(:wound, victim: susan_doe, location: 'Arm', severity: 3)
      create(:wound, victim: susan_doe, location: 'Leg', severity: 3)
      create(:wound, victim: shawn_doe, location: 'Arm', severity: 1)
      create(:wound, victim: shawn_doe, location: 'Leg', severity: 1)
    end

    before(:each) do
      stub_data
    end

    after(:each) do
      unset_action.perform
    end

    it 'returns self if model is the date_shift_root' do
      action.perform

      expect(@lion_monster.date_shift_root_record).to eq(@lion_monster)
    end

    it 'returns right record if an ancestor model is date_shift_root' do
      action.perform

      expect(@john_arm.date_shift_root_record).to eq(@lion_monster)
    end
    
    it 'returns nil if no ancestor model is date_shift_root' do
      expect(@john_arm.date_shift_root_record).to eq(nil)
    end
  end
end
