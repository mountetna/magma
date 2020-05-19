require_relative '../lib/magma'
require 'yaml'

describe Magma::Project do
  describe ".initialize" do
    it "loads attributes on the project's models from the database" do
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

      Magma.instance.db[:attributes].insert(
        project_name: "labors",
        model_name: "monster",
        attribute_name: "color",
        type: "string",
        created_at: Time.now,
        updated_at: Time.now,
        description: "What color is it?",
      )

      project = Magma::Project.new("./labors")
      # Fetch and delete test attributes so they don't affect other tests
      size_attribute = Labors::Monster.attributes.delete(:size)
      color_attribute = Labors::Monster.attributes.delete(:color)

      expect(size_attribute.display_name).to eq("Monster Size")
      expect(size_attribute.description).to eq("How big is this monster?")
      expect(size_attribute.unique).to be(true)
      expect(color_attribute.description).to eq("What color is it?")
    end

    it "loads link models on the project's models from the database" do
      Magma.instance.db[:attributes].insert(
        project_name: "labors",
        model_name: "monster",
        attribute_name: "alter_ego",
        type: "link",
        created_at: Time.now,
        updated_at: Time.now,
        link_model: "monster"
      )

      project = Magma::Project.new("./labors")
      # Fetch and delete test attribute so it doesn't affect other tests
      attribute = Labors::Monster.attributes.delete(:alter_ego)

      expect(attribute.link_model).to eq(Labors::Monster)
    end

    it "loads loaders on the project's models from the database" do
      Magma.instance.db[:attributes].insert(
        project_name: "labors",
        model_name: "monster",
        attribute_name: "origin_story",
        type: "file",
        created_at: Time.now,
        updated_at: Time.now,
        loader: "custom_origin_story_loader"
      )

      project = Magma::Project.new("./labors")
      # Fetch and delete test attribute so it doesn't affect other tests
      attribute = Labors::Monster.attributes.delete(:origin_story)

      expect(attribute.loader).to eq("custom_origin_story_loader")
    end

    it "gives database model attributes precedence over those defined in Ruby" do
      original_attribute = Labors::Monster.attributes[:name]

      Magma.instance.db[:attributes].insert(
        project_name: "labors",
        model_name: "monster",
        attribute_name: "name",
        type: "string",
        created_at: Time.now,
        updated_at: Time.now,
        description: "Only something I would know"
      )

      project = Magma::Project.new("./labors")
      attribute = Labors::Monster.attributes[:name]

      expect(attribute.description).to eq("Only something I would know")

      Labors::Monster.attributes[:name] = original_attribute
    end
  end
end
