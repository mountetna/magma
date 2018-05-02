describe Magma::Migration do
  before(:each) do
    allow(Magma.instance).to receive(:config).and_return(:default)
    allow(Magma.instance).to receive(:config).with(:project_path).and_return(:default)
  end

  it 'suggests a migration' do
  end
end
