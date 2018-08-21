require_relative '../gem/lib/client.rb'

describe Magma::Client do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  before(:each) do
    stub_request(:post, 'http://magma.test/retrieve').to_rack(app)
    stub_request(:post, 'http://magma.test/query').to_rack(app)
    stub_request(:post, 'http://magma.test/update').to_rack(app)
    @token = Base64.strict_encode64(AUTH_USERS[:editor].to_json)
  end

  def client
    Magma::Client.instance
  end

  it 'raises a client error for bad statuses' do
    response = nil
    expect do

      # This request has no record_name.
      response = client.retrieve(
        @token,
        'labors',
        {
          model_name: 'labor',
          attribute_names: [],
          project_name: 'labors'
        }
      )
    end.to raise_error(Magma::ClientError)
  end

  it 'invokes the retrieve endpoint correctly.' do
    response = nil
    expect do
      response = client.retrieve(
        @token,
        'labors',
        {
          model_name: 'labor',
          record_names: [],
          attribute_names: [],
          project_name: 'labors'
        }
      )
    end.to_not raise_error(Magma::ClientError)

    json = json_body(response.body)

    expect(json[:models].keys).to eq([:labor])
  end

  it 'invokes the update endpoint correctly.' do
    lion = create(:monster, name: 'Nemean Lion', species: 'hydra')

    expect do
      client.update(
        @token,
        'labors',
        {
          monster: {
            'Nemean Lion' => {
              species: 'lion'
            }
          }
        }
      )
    end.to_not raise_error(Magma::ClientError)

    lion.refresh
    expect(lion.species).to eq('lion')
  end

  it 'invokes the query endpoint correctly.' do
    create_list(:labor, 3)

    response = nil
    expect do
      response = client.query(
        @token,
        'labors',
        [ 'labor', '::all', '::identifier' ]
      )
    end.to_not raise_error(Magma::ClientError)

    json = json_body(response.body)

    expect(json[:answer].length).to eq(3)
  end
end
