describe Magma::Migration do
  before(:each) do
    #allow(Magma.instance).to receive(:config).and_return(:default)
    #allow(Magma.instance).to receive(:config).with(:project_path).and_return(:default)

    class Labors
      class Olympian < Magma::Model
        identifier :name
      end
    end
  end

  it 'suggests a migration' do
    Olympian.migration
  end
end
