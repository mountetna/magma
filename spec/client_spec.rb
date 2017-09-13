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

        # Note that we are neither testing #post nor #multipart_post
        allow(client).to receive(:multipart_post) do |endpoint, content|
          path = "/#{endpoint}"
          multipart = Net::HTTP::Post::Multipart.new(path, content)
          body = multipart.body_stream.read
          content_type = multipart.to_hash["content-type"].first

          post(
            "/#{endpoint}",
            body,
            'CONTENT_TYPE' => content_type
          )
          last_response.define_singleton_method(:code) do
            status
          end
          last_response
        end

        allow(client).to receive(:post) do |endpoint, content_type, body|
          post("/#{endpoint}", body, { 'CONTENT_TYPE'=> content_type })
          last_response.define_singleton_method(:code) do
            status
          end
          last_response
        end

        client
      end
  end

  it "invokes the retrieve endpoint correctly." do
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
   
    json = json_body(payload)

    expect(status).to eq(200)
    expect(json[:models].keys).to eq([:labor])
  end 

  it "invokes the update endpoint correctly." do
    token = 'janus-token'
    lion = create(:monster, name: 'Nemean Lion', species: 'hydra')

    status = nil
    payload = nil
    expect do
      status, payload = client.update(
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
    end.to_not raise_error
   
    lion.refresh
    expect(status).to eq(200)
    expect(lion.species).to eq('lion')
  end
  
  it "invokes the query endpoint correctly." do
    token = 'janus-token'
    create_list(:labor, 3)

    status = nil
    payload = nil
    expect do
      status, payload = client.query(
        token,
        'labors',
        [ 'labor', '::all', '::identifier' ]
      )
    end.to_not raise_error
   
    json = json_body(payload)

    expect(status).to eq(200)
    expect(json[:answer].length).to eq(3)
  end
end


