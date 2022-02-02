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

  describe 'is_date_shift_root?' do
    after(:each) do
      set_date_shift_root("monster", false)
    end

    it 'returns true if model is the date_shift_root' do
      set_date_shift_root("monster", true)

      expect(Labors::Monster.is_date_shift_root?).to eq(true)
      expect(Labors::Victim.is_date_shift_root?).to eq(false)
    end
  end

  describe 'path_to_date_shift_root model' do
    after(:each) do
      set_date_shift_root("monster", false)
    end

    it 'returns path when model is the date_shift_root model' do
      set_date_shift_root("monster", true)

      expect(Labors::Monster.path_to_date_shift_root).to eq([Labors::Monster])
      expect(Labors::Labor.path_to_date_shift_root).to eq([])
    end

    it 'returns correct path when date_shift_root model is ancestor' do
      set_date_shift_root("monster", true)

      expect(Labors::Victim.path_to_date_shift_root).to eq([Labors::Victim, Labors::Monster])
      expect(Labors::Wound.path_to_date_shift_root).to eq([Labors::Wound, Labors::Victim, Labors::Monster])
      expect(Labors::Prize.path_to_date_shift_root).to eq([])
    end

    it 'returns empty list when no path found' do
      expect(Labors::Monster.path_to_date_shift_root).to eq([])
      expect(Labors::Victim.path_to_date_shift_root).to eq([])
    end
  end

  it 'can get column names' do
    expect(Labors::Monster.column_name(attribute_type: Magma::IdentifierAttribute)).to eq(:name)
    expect(Labors::Monster.column_name(attribute_name: :reference_monster)).to eq(:reference_monster_id)
  end
end
