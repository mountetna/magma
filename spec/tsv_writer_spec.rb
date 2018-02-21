require 'rspec'

describe 'TSVWriter' do

  it 'should write a tsv with all attributes and records from model, retrieval, and payload' do
    project = create(:project, name: 'The Twelve Labors of Hercules')
    labors = create_list(:labor, 3, project: project)

    model = Magma.instance.get_model('labors', 'labor')

    retrieval = Magma::Retrieval.new(
        model,
        nil,
        model.attributes.values,
        nil
    )

    class MockFile
      attr_reader :lines
      def initialize
        @lines = []
      end

      def << line
        @lines.push(line)
      end
    end

    file = MockFile.new
    payload = Magma::Payload.new
    TSVWriter.new(model, retrieval, payload).write_tsv(file)

    header = "project\tname\tmonster\tnumber\tcompleted\tyear\n"
    expect(file.lines[0]).to eq(header)

    rows_count = file.lines[1].split("\n").size
    expect(rows_count).to eq(3)
  end
end