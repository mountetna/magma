load_magma

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
end
