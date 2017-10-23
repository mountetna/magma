describe Magma::Loader do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  it 'bulk-creates records' do
    loader = Magma::Loader.new

    loader.push_record(Labors::Labor, name: 'Nemean Lion', number: 1, completed: true)
    loader.push_record(Labors::Labor, name: 'Lernean Hydra', number: 2, completed: false)
    loader.push_record(Labors::Labor, name: 'Augean Stables', number: 5, completed: false)

    loader.dispatch_record_set

    expect(Labors::Labor.count).to eq(3)
  end

  it 'bulk-updates records' do
    lion = create(:labor, name: 'Nemean Lion', number: 1, completed: false)
    hydra = create(:labor, name: 'Lernean Hydra', number: 2, completed: false)

    loader = Magma::Loader.new

    loader.push_record(Labors::Labor, name: 'Nemean Lion', number: 1, completed: true)
    loader.push_record(Labors::Labor, name: 'Augean Stables', number: 5, completed: false)

    loader.dispatch_record_set
    lion.refresh

    expect(Labors::Labor.count).to eq(3)
    expect(lion.completed).to eq(true)
  end

  it 'validates records' do
    loader = Magma::Loader.new
    loader.push_record(Labors::Monster, name: 'Nemean Lion', species: 'Lion')

    expect { loader.dispatch_record_set }.to raise_error(Magma::LoadFailed)
  end

  it 'creates associations' do
    loader = Magma::Loader.new
    loader.push_record(Labors::Labor, temp_id: loader.temp_id(:lion), name: 'Nemean Lion')
    loader.push_record(Labors::Prize, temp_id: loader.temp_id(:hide), labor: loader.temp_id(:lion), name: 'hide')

    loader.dispatch_record_set
    lion = Labors::Labor[name: 'Nemean Lion']

    expect(lion.prize.first.name).to eq('hide')
  end
end
