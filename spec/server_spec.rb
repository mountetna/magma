describe 'Magma::Server' do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  it 'shows little at the root.' do
    auth_header(:viewer)
    get '/'
    expect(last_response).to(be_ok)
    expect(last_response.body).to(eq('Magma On.'))
  end
end
