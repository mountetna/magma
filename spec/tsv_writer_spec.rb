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
    header = lines[0]
    expect(header).to eq(payload.tsv_header.sub("\n", ''))
    expect(lines.size).to eq(5)

    name_index = header.split("\t").find_index("name")
    tsv_labors_names = lines.drop(1).map { |l| l.split("\t")[name_index] }.sort
    labors_names = labors.map(&:name).sort
    expect(tsv_labors_names).to eq(labors_names)
  end
end