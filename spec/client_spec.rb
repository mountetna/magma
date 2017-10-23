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
    @client ||= 
      begin
        client = @configuration_class.instance

        # Note that we are neither testing #post nor #multipart_post.
        allow(client).to receive(:multipart_post) do |endpoint, content|

          path = "/#{endpoint}"
          multipart = Net::HTTP::Post::Multipart.new(path, content)
          body = multipart.body_stream.read
          content_type = multipart.to_hash['content-type'].first

          post("/#{endpoint}", body, 'CONTENT_TYPE'=> content_type)

          last_response.define_singleton_method(:code) do
            status
          end
          last_response
        end

        allow(client).to receive(:post) do |endpoint, content_type, body|

          post("/#{endpoint}", body, {'CONTENT_TYPE'=> content_type})

          last_response.define_singleton_method(:code) do
            status
          end

          last_response
        end

        client
      end
  end

  it 'invokes the retrieve endpoint correctly.' do
    token = 'janus-token'

    response = nil
    expect do
      response = client.retrieve(
        token,
        'labors',
        {
          project_name: 'labors',
          model_name: 'labor',
          record_names: [],
          attribute_names: []
        }
      )
    end.to_not raise_error(Magma::ClientError)

    json = json_body(response.body)

    expect(json[:models].keys).to eq([:labor])
  end

  it 'invokes the update endpoint correctly.' do
    token = 'janus-token'
    lion = create(:monster, name: 'Nemean Lion', species: 'hydra')

    expect do
      client.update(
        token,
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
    token = 'janus-token'
    create_list(:labor, 3)

    response = nil
    expect do
      response = client.query(
        token,
        'labors',
        [ 'labor', '::all', '::identifier' ]
      )
    end.to_not raise_error(Magma::ClientError)

    json = json_body(response.body)

    expect(json[:answer].length).to eq(3)
  end
end


