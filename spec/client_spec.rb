require_relative '../gem/lib/client.rb'

describe Magma::Client do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  before(:each) do
    @configuration_class = Magma::Client.clone
    @client = nil
  end

  def client
    @client ||= @configuration_class.instance
  end

  def client_post endpoint, content_type, body
    post("/#{endpoint}", body, { 'CONTENT_TYPE'=> content_type })
    last_response.define_singleton_method(:code) do
      status
    end
    last_response
  end

  it "invokes the retrieve endpoint correctly." do
    allow(client).to receive(:post) do |endpoint, content_type, body|
      client_post(endpoint,content_type, body)
    end

    token = 'janus-token'

    status = nil
    payload = nil
    expect do
      status, payload = client.retrieve(
        token,
        'labors',
        {
          model_name: "labor",
          record_names: [],
          attribute_names: [],
          project_name: "labors"
        }
      )
    end.to_not raise_error(Magma::ClientError)
   
    json = JSON.parse(payload, symbolize_names: true)

    expect(status).to eq(200)
    expect(json[:models].keys).to eq([:labor])
  end
end


