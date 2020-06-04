describe UpdateModelController do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  it "updates attribute options" do
    auth_header(:editor)
    json_post(:update_model, {
      project_name: "labors",
      actions: [
        action_name: "update_attribute",
        model_name: "monster",
        attribute_name: "name",
        description: "The monster's name",
        display_name: "NAME"
      ]
    })

    expect(last_response.status).to eq(200)
    expect(Labors::Monster.attributes[:name].description).to eq("The monster's name")
    expect(Labors::Monster.attributes[:name].display_name).to eq("NAME")
  end
end
