describe UpdateModelController do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  let(:proper_name) { 'name' }
  let(:improper_name) { 'namex' }

  it "rejects requests from non-superusers" do
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

  it "updates attribute options" do
    original_attribute = Labors::Monster.attributes[:name].dup

    auth_header(:superuser)
    json_post(:update_model, {
      project_name: "labors",
      actions: [{
        action_name: "update_attribute",
        model_name: "monster",
        attribute_name: proper_name,
        description: "The monster's name",
        display_name: "NAME"
      }]
    })
    
    expect(last_response.status).to eq(200)
    expect(Labors::Monster.attributes[:name].description).to eq("The monster's name")
    expect(Labors::Monster.attributes[:name].display_name).to eq("NAME")

    response_json = JSON.parse(last_response.body)
    attribute_json = response_json["models"]["monster"]["template"]["attributes"]["name"]
    expect(attribute_json["desc"]).to eq("The monster's name")
    expect(attribute_json["display_name"]).to eq("NAME")

    Labors::Monster.attributes[:name] = original_attribute
  end

  describe "does not update" do
    it "does not update attribute options with invalid attribute name" do
      auth_header(:superuser)
      json_post(:update_model, {
        project_name: "labors",
        actions: [{
          action_name: "update_attribute",
          model_name: "monster",
          attribute_name: improper_name,
          display_name: "NAME"
        }]
      })

      response_json = JSON.parse(last_response.body)
      expect(last_response.status).to eq(422)
      expect(response_json['errors'][0]['message']).to eq('Attribute does not exist')

      # Other options are not changed if an update fails
      expect(Labors::Monster.attributes[:name].display_name).not_to eq("NAME")
    end

    it "does not update attribute options with the invalid data type" do
      auth_header(:superuser)
      json_post(:update_model, {
        project_name: "labors",
        actions: [{
          action_name: "update_attribute",
          model_name: "monster",
          attribute_name: proper_name,
          validation: 23,
          display_name: "NAME"
        }]
      })

      response_json = JSON.parse(last_response.body)

      expect(last_response.status).to eq(422)
      expect(response_json['errors'][0]['message']).to eq("Update attribute failed")
      expect(response_json['errors'][0]['reason']).to eq("validation is not properly formatted")

      # Other options are not changed if an update fails
      expect(Labors::Monster.attributes[:name].display_name).not_to eq("NAME")
    end

    it "does not update attribute_name" do
      expected = {
        :message=>"new_attribute_name cannot be changed", 
        :source=>{
          :action_name=>"update_attribute", 
          :model_name=>"monster", 
          :attribute_name=>"name"
        }, 
        :reason=>nil
      }

      auth_header(:superuser)
      json_post(:update_model, {
        project_name: "labors",
        actions: [{
          action_name: "update_attribute",
          model_name: "monster",
          attribute_name: proper_name,
          new_attribute_name: 'new_name'
        }]
      })

      expect(last_response.status).to eq(422)
      expect(json_body[:errors][0]).to eq(expected)
    end

    it "does not update name" do
      expected = {
        :message=>"name cannot be changed", 
        :source=>{
          :action_name=>"update_attribute", 
          :model_name=>"monster", 
          :attribute_name=>"name"
        }, 
        :reason=>nil
      }

      auth_header(:superuser)
      json_post(:update_model, {
        project_name: "labors",
        actions: [{
          action_name: "update_attribute",
          model_name: "monster",
          attribute_name: proper_name,
          name: 'new_name'
        }]
      })

      expect(last_response.status).to eq(422)
      expect(json_body[:errors][0]).to eq(expected)
    end
  end
end
