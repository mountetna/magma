describe UpdateModelController do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  context "requests from non-superusers" do
    it "rejects the requests" do
      auth_header(:editor)

      json_post(:update_model, {
        project_name: "labors",
        actions: [
          action_name: "update_attribute",
          model_name: "monster",
          attribute_name: "name",
          description: "The monster's name",
        ]
      })

      expect(last_response.status).to eq(403)
    end
  end

  context "valid and authorized request" do
    before do
      @original_attribute = Labors::Monster.attributes[:name].dup
    end

    after do
      Labors::Monster.attributes[:name] = @original_attribute
    end

    it "returns the project template with all changes" do
      auth_header(:superuser)
      json_post(:update_model, {
        project_name: "labors",
        actions: [{
          action_name: "update_attribute",
          model_name: "monster",
          attribute_name: "name",
          description: "The monster's name",
          display_name: "NAME"
        }]
      })

      expect(last_response.status).to eq(200)

      response_json = JSON.parse(last_response.body)
      attribute_json = response_json["models"]["monster"]["template"]["attributes"]["name"]
      expect(attribute_json["desc"]).to eq("The monster's name")
      expect(attribute_json["display_name"]).to eq("NAME")
    end
  end

  context "invalid action" do
    it "does not update attribute options with invalid attribute name" do
      auth_header(:superuser)
      json_post(:update_model, {
        project_name: "labors",
        actions: [{
          action_name: "update_attribute",
          model_name: "monster",
          attribute_name: "something_invalid",
          display_name: "NAME"
        }]
      })

      response_json = JSON.parse(last_response.body)
      expect(last_response.status).to eq(422)
      expect(response_json['errors'][0]['message']).to eq('Attribute does not exist')

      # No other changes are made when actions fail
      expect(Labors::Monster.attributes[:name].display_name).not_to eq("NAME")
    end
  end
end
