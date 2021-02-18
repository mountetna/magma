describe Magma::Loader do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  before(:each) do
    @user = Etna::User.new(
        email: 'zeus@mountolympus.org',
        name: 'Zeus',
        perm: 'A:labors'
    )
  end

  it 'bulk-creates records' do
    loader = Magma::Loader.new(@user, 'labors')
    loader.push_record(Labors::Labor, 'Nemean Lion', number: 1, completed: true)
    loader.push_record(Labors::Labor, 'Lernean Hydra', number: 2, completed: false)
    loader.push_record(Labors::Labor, 'Augean Stables', number: 5, completed: false)

    loader.dispatch_record_set

    expect(Labors::Labor.count).to eq(3)
  end

  it 'bulk-creates records with different data' do
    loader = Magma::Loader.new(@user, 'labors')
    loader.push_record(Labors::Labor, 'Nemean Lion', number: 1)
    loader.push_record(Labors::Labor, 'Lernean Hydra', completed: false)
    loader.push_record(Labors::Labor, 'Augean Stables', number: 5)

    loader.dispatch_record_set

    expect(Labors::Labor.count).to eq(3)

    lion = Labors::Labor[name: 'Nemean Lion']
    hydra = Labors::Labor[name: 'Lernean Hydra']

    expect(lion.number).to eq(1)
    expect(lion.completed).to be_nil
    expect(hydra.number).to be_nil
    expect(hydra.completed).to eq(false)
  end

  it 'bulk-updates records' do
    lion = create(:labor, name: 'Nemean Lion', number: 1, completed: false)
    hydra = create(:labor, name: "Lernean Hydra", number: 2, completed: false)

    loader = Magma::Loader.new(@user, 'labors')
    loader.push_record(Labors::Labor, 'Nemean Lion', number: 1, completed: true)
    loader.push_record(Labors::Labor, 'Augean Stables', number: 5, completed: false)

    loader.dispatch_record_set
    lion.refresh

    expect(Labors::Labor.count).to eq(3)
    expect(lion.completed).to eq(true)
  end

  it 'bulk-updates records with different data' do
    lion = create(:labor, name: 'Nemean Lion', number: 1, completed: false)
    hydra = create(:labor, name: "Lernean Hydra", number: 3, completed: false)

    loader = Magma::Loader.new(@user, 'labors')
    loader.push_record(Labors::Labor, 'Nemean Lion', completed: true)
    loader.push_record(Labors::Labor, 'Lernean Hydra', number: 2)

    loader.dispatch_record_set

    expect(Labors::Labor.count).to eq(2)

    lion = Labors::Labor[name: 'Nemean Lion']
    hydra = Labors::Labor[name: 'Lernean Hydra']

    expect(lion.number).to eq(1)
    expect(lion.completed).to eq(true)
    expect(hydra.number).to eq(2)
    expect(hydra.completed).to eq(false)
  end

  it 'validates records' do
    loader = Magma::Loader.new(@user, 'labors')
    loader.push_record(Labors::Monster, 'Nemean Lion', species: 'Lion')

    expect { loader.dispatch_record_set }.to raise_error(Magma::LoadFailed)
  end

  it 'creates associations' do
    loader = Magma::Loader.new(@user, 'labors')
    loader.push_record(Labors::Labor, 'Nemean Lion', species: 'Lion', prize: [ '::temphide' ]) 
    loader.push_record(Labors::Prize, '::temphide', labor: 'Nemean Lion', name: 'hide')

    loader.dispatch_record_set
    lion = Labors::Labor[name: 'Nemean Lion']

    expect(lion.prize.first.name).to eq('hide')
  end
end
