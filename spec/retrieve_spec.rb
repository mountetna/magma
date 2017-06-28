describe Magma::Server::Retrieve do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  it "calls the retrieve endpoint and returns a template" do
    post(
      '/retrieve', 
      {
        model_name: "labor",
        record_names: [],
        attribute_names: []
      }.to_json,
      {
        'CONTENT_TYPE' => 'application/json'
      }
    )
    expect(last_response).to be_ok
  end

  it "complains with missing params" do
    post(
      '/retrieve',
      {
      }.to_json,
      {
        'CONTENT_TYPE' => 'application/json'
      }
    )
    expect(last_response.status).to eq(422)
  end

  it "can get all models from the retrieve endpoint" do
    post(
      '/retrieve', 
      {
        model_name: "all",
        record_names: [],
        attribute_names: []
      }.to_json,
      {
        'CONTENT_TYPE' => 'application/json'
      }
    )
    expect(last_response).to be_ok
  end

  it "retrieves records by name" do
    labors = create_list(:labor,3)

    post(
      '/retrieve', 
      {
        model_name: "all",
        record_names: labors[0..1].map(&:name),
        attribute_names: "all" 
      }.to_json,
      {
        'CONTENT_TYPE' => 'application/json'
      }
    )

    json = JSON.parse(last_response.body)

    expect(json["models"]["labor"]["documents"]).to have_key(labors[0].name)
    expect(json["models"]["labor"]["documents"]).not_to have_key(labors[2].name)
  end

  it "can retrieve a TSV of data from the endpoint" do
    labor_list = create_list(:labor, 3)
    post(
      '/retrieve', 
      {
        model_name: "labor",
        record_names: "all",
        attribute_names: "all",
        format: "tsv"
      }.to_json,
      {
        'CONTENT_TYPE' => 'application/json'
      }
    )
    # strong assumption about how columns should be ordered, may
    # be inappropriate for this test - unavoidable?
    expect(last_response.body.split(/\n/).length).to eq(4)
  end
end
