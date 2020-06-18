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

  describe '#create_attribute' do
    let(:model) { Labors::Monster }
    let(:attribute_options) do
      {
        project_name: 'Labors',
        model_name: 'Monster',
        attribute_name: 'new_attribute_name',
        description: "description",
        display_name: "name",
        format_hint: "incoming format hint",
        hidden: true,
        index: false,
        link_model_name: "species",
        read_only: true,
        restricted: false,
        unique: true,
        type: "string",
        validation: {"type": "Regexp", "value": "^[a-z\\s]+$"}
      }
    end

    it 'creates an attribute'  do
      model.create_attribute(attribute_options)
      expect(model.attributes[:new_attribute_name]).not_to be_nil
    end
  end
end
