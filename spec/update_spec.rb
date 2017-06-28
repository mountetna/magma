describe Magma::Server::Update do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  it "posts content to an endpoint" do
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
end
