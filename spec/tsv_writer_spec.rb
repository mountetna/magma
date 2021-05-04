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
        model.attributes.values.map { |a| a.name.to_sym },
        filter: nil,
        page: 1,
        page_size: 5
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

  it 'can transpose the resulting data' do
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
    Magma::TSVWriter.new(
      model,
      retrieval,
      payload,
      expand_matrices: true,
      transpose: true).write_tsv{ |lines| file.write lines }

    lines = file.string.split("\n")
    header = lines.map { |l| l.split("\t").first }

    expect(lines.length).to eq(5)
    model.attributes[:contributions].validation_object.options.each do |opt|
      expect(header.include?("contributions.#{opt}")).to eq(true)
    end

    labors_names = labors.map(&:name).sort
    expect(lines.first).to eq(["name"].concat(labors_names).join("\t"))
  end

  it 'should contain expanded matrix header if expand_matrices' do
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
    Magma::TSVWriter.new(
      model,
      retrieval,
      payload,
      expand_matrices: true).write_tsv{ |lines| file.write lines }

    lines = file.string.split("\n")
    header = lines[0]
    model.attributes[:contributions].validation_object.options.each do |opt|
      expect(header.include?("contributions.#{opt}")).to eq(true)
    end
    expect(lines[1].count("\t")).to eq(4)
  end

  it 'should not contain expanded matrix header if not expand_matrices' do
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
      expect(header.include?("contributions.#{opt}")).to eq(false)
    end
    expect(header.include?("contributions")).to eq(true)
    expect(lines[1].count("\t")).to eq(1)
  end

  it 'should contain expanded matrix headers with output_predicate if expand_matrices' do
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
    Magma::TSVWriter.new(
      model,
      retrieval,
      payload,
      expand_matrices: true).write_tsv{ |lines| file.write lines }

    lines = file.string.split("\n")
    header = lines[0]
    expect(header.include?("contributions.Sidon")).to eq(true)
    expect(header.include?("contributions.Athens")).to eq(false)
    expect(header.include?("contributions\n")).to eq(false)
    expect(lines[1].count("\t")).to eq(1)
  end

  it 'should contain only matrix attribute name even with output_predicate if not expand_matrices' do
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
    expect(header.include?("contributions.Sidon")).to eq(false)
    expect(header.include?("contributions")).to eq(true)
    expect(lines[1].count("\t")).to eq(1)
  end
end
