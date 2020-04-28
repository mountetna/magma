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

  describe ".load_attributes" do
    it "loads attributes defined in the database" do
      Magma.instance.db[:attributes].insert(
        project_name: "labors",
        model_name: "monster",
        attribute_name: "size",
        type: "string",
        created_at: Time.now,
        updated_at: Time.now,
        display_name: "Monster Size",
        description: "How big is this monster?",
        unique: true
      )

      Labors::Monster.load_attributes
      # Fetch and delete attribute so it doesn't affect other tests
      attribute = Labors::Monster.attributes.delete(:size)

      expect(attribute.display_name).to eq("Monster Size")
      expect(attribute.description).to eq("How big is this monster?")
      expect(attribute.unique).to be(true)
    end

    it "loads link models defined in the database" do
      Magma.instance.db[:attributes].insert(
        project_name: "labors",
        model_name: "monster",
        attribute_name: "alter_ego",
        type: "link",
        created_at: Time.now,
        updated_at: Time.now,
        link_model: "monster"
      )

      Labors::Monster.load_attributes
      # Fetch and delete attribute so it doesn't affect other tests
      attribute = Labors::Monster.attributes.delete(:alter_ego)

      expect(attribute.link_model).to eq(Labors::Monster)
    end

    it "loads loaders defined in the database" do
      Magma.instance.db[:attributes].insert(
        project_name: "labors",
        model_name: "monster",
        attribute_name: "origin_story",
        type: "file",
        created_at: Time.now,
        updated_at: Time.now,
        loader: "custom_origin_story_loader"
      )

      Labors::Monster.load_attributes
      # Fetch and delete attribute so it doesn't affect other tests
      attribute = Labors::Monster.attributes.delete(:origin_story)

      expect(attribute.loader).to eq("custom_origin_story_loader")
    end
  end
end
