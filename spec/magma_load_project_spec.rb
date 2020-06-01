describe Magma::LoadProject do
  let(:json_file) { './spec/fixtures/template.json' }

  subject(:load_project) { described_class.new.execute('project_name', json_file) }

  let(:attributes) { Magma.instance.db[:attributes] }

  it 'loads attributes into the database' do
    json_attributes = JSON.parse(JSON.parse(File.open(json_file).read))["models"]["aspect"]["template"]["attributes"]
    model_json_template = JSON.parse(Labors::Aspect.json_template.to_json)["attributes"]

    expect {
      load_project
    }.to change { attributes.count }.by(6)
    expect(json_attributes).to eq(model_json_template)
  end
end
