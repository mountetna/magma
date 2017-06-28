require 'pry'
describe Magma::Server::Update do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  it "can post a basic query" do
    lion = create(:labor, name: "Nemean Lion", number: 1, completed: true)
    hydra = create(:labor, name: "Lernean Hydra", number: 2, completed: false)
    stables = create(:labor, name: "Augean Stables", number: 5, completed: false)

    hide = create(:prize, labor: lion, name: "hide", worth: 5)
    poison = create(:prize, labor: hydra, name: "poison", worth: 5)
    poop = create(:prize, labor: hydra, name: "poop", worth: 0)
    post(
      '/query',
      {
        query: [ 'labor', [ 'prize', [ 'worth', '::>', 2 ], '::first', 'worth', '::>', 2 ], '::all', '::identifier' ]
      }.to_json,
      {
        'CONTENT_TYPE' => 'application/json'
      }
    )

    json = JSON.parse(last_response.body)
    expect(json["answer"].length).to eq(2)
  end
end
