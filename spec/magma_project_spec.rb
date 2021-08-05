require_relative '../lib/magma'
require 'yaml'

describe Magma::Project do
  describe ".initialize" do
    it "loads attributes on the project's models from the database" do
      Magma.instance.db[:attributes].insert(
        project_name: "labors",
        model_name: "monster",
        attribute_name: "size",
        column_name: "size",
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
        column_name: "color",
        type: "string",
        created_at: Time.now,
        updated_at: Time.now,
        description: "What color is it?",
      )

      project = Magma::Project.new(project_dir: "./labors")
      # Fetch and delete test attributes so they don't affect other tests
      size_attribute = Labors::Monster.attributes.delete(:size)
      color_attribute = Labors::Monster.attributes.delete(:color)

      expect(size_attribute.display_name).to eq("Monster Size")
      expect(size_attribute.description).to eq("How big is this monster?")
      expect(size_attribute.unique).to be(true)
      expect(color_attribute.description).to eq("What color is it?")
    end

    it "loads link models defined in the database" do
      Magma.instance.db[:attributes].insert(
        project_name: "labors",
        model_name: "monster",
        attribute_name: "alter_ego",
        column_name: "alter_ego",
        type: "link",
        created_at: Time.now,
        updated_at: Time.now,
        link_model_name: "monster"
      )

      project = Magma::Project.new(project_dir: "./labors")
      # Fetch and delete test attributes so they don't affect other tests
      attribute = Labors::Monster.attributes.delete(:alter_ego)

      expect(attribute.link_model).to eq(Labors::Monster)
    end

    it "gives database model attributes precedence over those defined in Ruby" do
      project = Magma::Project.new(project_dir: "./spec/fixtures/movies")
      original_attribute = Movies::Villain.attributes[:name]

      Magma.instance.db[:attributes].insert(
        project_name: "movies",
        model_name: "villain",
        attribute_name: "name",
        column_name: "name",
        type: "string",
        created_at: Time.now,
        updated_at: Time.now,
        description: "Only something I would know"
      )

      project = Magma::Project.new(project_dir: "./spec/movies")
      attribute = Movies::Villain.attributes[:name]

      expect(attribute.description).to eq("Only something I would know")

      Movies::Villain.attributes[:name] = original_attribute
    end

    it "raises an error when the database has attributes for a model that doesn't exist" do
      Magma.instance.db[:attributes].insert(
        project_name: "labors",
        model_name: "ghost",
        attribute_name: "name",
        column_name: "name",
        type: "string",
        created_at: Time.now,
        updated_at: Time.now,
        description: "There isn't a Labors::Ghost model"
      )

      expect { Magma::Project.new(project_dir: "./labors") }.to(
        raise_error(Magma::Project::AttributeLoadError)
      )
    end

    it "loads the project model's from the database" do
      Magma.instance.db[:models].insert(
        project_name: "movies",
        model_name: "hero",
        created_at: Time.now,
        updated_at: Time.now
      )

      Magma.instance.db[:models].insert(
          project_name: "movies",
          model_name: "status",
          created_at: Time.now,
          updated_at: Time.now
      )

      Magma.instance.db[:attributes].insert(
        project_name: "movies",
        model_name: "hero",
        attribute_name: "name",
        column_name: "name",
        type: "string",
        created_at: Time.now,
        updated_at: Time.now,
        description: "The hero's name"
      )

      project = Magma::Project.new(project_name: :movies)

      expect(project.models[:hero]).to eq(Movies::Hero)
      expect(Movies::Hero.attributes[:name].description).to eq("The hero's name")

      expect(project.models[:status]).to eq(Movies::Status)
    end
  end

  describe '.ordered_models' do
    let(:project) { Magma.instance.magma_projects[:labors] }
    let(:model) { project.models[:monster] }

    it 'returns ordered models for labors project' do
      expect(project.ordered_models(model)).to match_array([Labors::Victim, Labors::Aspect, Labors::Wound])
    end
  end
end
