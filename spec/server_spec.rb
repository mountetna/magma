require 'rack/test'

ENV['RACK_ENV'] = 'test'

OUTER_APP = Rack::Builder.parse_file("config.ru").first

require 'rspec'
require 'rack/test'

describe 'Magma::Server' do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  it "shows little at the root" do
    get '/'
    expect(last_response).to be_ok
    expect(last_response.body).to eq('::magma::')
  end

  it "calls the retrieve endpoint and returns a record" do
    post '/retrieve', 
      model_name: "all",
      record_names: [],
      attribute_names: ""
    expect(last_response).to be_ok
  end
end
