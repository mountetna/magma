describe Magma::Server::Update do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  it "can update content" do
    lion = create(:monster, name: "Nemean Lion", species: "hydra")
    post(
      '/update',
      {
        revisions: {
          "monster" => {
            "Nemean Lion" => {
              species: "lion"
            }
          }
        }
      }.to_json,
      {
        'CONTENT_TYPE' => 'application/json'
      }
    )
    lion.refresh
    expect(lion.species).to eq('lion')
  end

  it "fails on validation checks" do
    # The actual validation is defined in spec/labors/models/monster.rb,
    # not sure how to move it here
    lion = create(:monster, name: "Nemean Lion", species: "hydra")
    post(
      '/update',
      {
        revisions: {
          "monster" => {
            "Nemean Lion" => {
              species: "Lion"
            }
          }
        }
      }.to_json,
      {
        'CONTENT_TYPE' => 'application/json'
      }
    )
    lion.refresh
    expect(last_response.status).to eq(422)
    expect(lion.species).to eq('hydra')
  end
end
