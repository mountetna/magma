describe Magma::Server do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  def retrieve(post, user_type=:viewer)
    auth_header(user_type)
    json_post(:retrieve, post)
  end

  it 'fails for non-users' do
    get('/')

    expect(last_response.status).to eq(401)
  end

  it 'shows magma is available for users' do
    auth_header(:viewer)
    get('/')

    expect(last_response.status).to eq(200)
    expect(last_response.body).to eq('Magma is available.')
  end
end

