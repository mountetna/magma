require 'rspec'

describe 'TSVWriter' do

  it 'should write a tsv with all attributes and records from model, retrieval, and payload' do
    project = create(:project, name: 'The Twelve Labors of Hercules')
    labors = create_list(:labor, 4, project: project)

    payload = Magma::Payload.new
    model = Magma.instance.get_model('labors', 'labor')
    retrieval = Magma::Retrieval.new(
        model,
        nil,
        model.attributes.values,
        nil,
        1,
        2
    )

    file = StringIO.new
    Magma::TSVWriter.new(model, retrieval, payload).write_tsv{ |lines| file.write lines }

    lines = file.string.split("\n")
    expect(lines[0]).to eq(payload.tsv_header.sub("\n", ''))
    expect(lines.size).to eq(5)
  end
end