describe Magma::Loader do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  it "bulk-creates records" do
    loader = Magma::Loader.new
    loader.push_record(Labor, name: "Nemean Lion", number: 1, completed: true)
    loader.push_record(Labor, name: "Lernean Hydra", number: 2, completed: false)
    loader.push_record(Labor, name: "Augean Stables", number: 5, completed: false)

    loader.dispatch_record_set

    expect(Labor.count).to eq(3)
  end

  it "validates records" do
    loader = Magma::Loader.new
    loader.push_record(Monster, name: "Nemean Lion", species: "Lion")

    expect { loader.dispatch_record_set}.to raise_error(Magma::LoadFailed)
  end
end
