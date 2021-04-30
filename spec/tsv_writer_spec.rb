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
        filter: nil,
        page: 1,
        page_size: 5
    )

    file = StringIO.new
    Magma::TSVWriter.new(model, retrieval, payload).write_tsv{ |lines| file.write lines }

    lines = file.string.split("\n")
    header = lines[0]
    expect(header).to eq(payload.tsv_header(retrieval.predicate_manager).sub("\n", ''))
    expect(lines.size).to eq(5)

    name_index = header.split("\t").find_index("name")
    tsv_labors_names = lines.drop(1).map { |l| l.split("\t")[name_index] }.sort
    labors_names = labors.map(&:name).sort
    expect(tsv_labors_names).to eq(labors_names)
  end

  it 'should contain unmelted matrix headers' do
    project = create(:project, name: 'The Twelve Labors of Hercules')
    labors = create_list(:labor, 4, project: project)

    payload = Magma::Payload.new
    model = Magma.instance.get_model('labors', 'labor')
    retrieval = Magma::Retrieval.new(
        model,
        nil,
        [:contributions],
        filter: nil,
        page: 1,
        page_size: 5
    )

    file = StringIO.new
    Magma::TSVWriter.new(model, retrieval, payload).write_tsv{ |lines| file.write lines }

    lines = file.string.split("\n")
    header = lines[0]
    model.attributes[:contributions].validation_object.options.each do |opt|
      expect(header.include?("contributions_#{opt}")).to eq(true)
    end
  end

  it 'should contain unmelted matrix headers with output_predicate' do
    project = create(:project, name: 'The Twelve Labors of Hercules')
    labors = create_list(:labor, 4, project: project)

    payload = Magma::Payload.new
    model = Magma.instance.get_model('labors', 'labor')
    retrieval = Magma::Retrieval.new(
        model,
        nil,
        [:contributions],
        filter: nil,
        page: 1,
        page_size: 5,
        output_predicates: [ Magma::Retrieval::StringOutputPredicate.new("contributions[]Sidon") ]
    )

    file = StringIO.new
    Magma::TSVWriter.new(model, retrieval, payload).write_tsv{ |lines| file.write lines }

    lines = file.string.split("\n")
    header = lines[0]
    expect(header.include?("contributions_Sidon")).to eq(true)
    expect(header.include?("contributions_Athens")).to eq(false)
  end
end
