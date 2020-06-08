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
  end

  it "does not update attribute options with invalid attribute name" do
    auth_header(:superuser)
    json_post(:update_model, {
      project_name: "labors",
      actions: [{
        action_name: "update_attribute",
        model_name: "monster",
        attribute_name: improper_name,
        description: "The monster's name",
        display_name: "NAME"
      }]
    })
    
    expect(last_response.status).to eq(500)
  end


  it "does not update attribute options with the incorrect data type" do
    auth_header(:superuser)
    json_post(:update_model, {
      project_name: "labors",
      actions: [{
        action_name: "update_attribute",
        model_name: "monster",
        attribute_name: 123,
        description: "The monster's name",
        display_name: "NAME"
      }]
    })

    expect(last_response.status).to eq(500)
  end
end
