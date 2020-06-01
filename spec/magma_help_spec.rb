describe Magma::Help do
  subject(:help) { described_class.new.execute }

  let(:magma_instance) { double('Magma') }
  let(:command_double) { double('command', usage: 'Usage') }
  let(:expected) { "Commands:\nUsage\n" }

  before do
    allow(Magma).to receive(:instance).and_return(magma_instance)
    allow(magma_instance).to receive(:commands).and_return({"test" => command_double})
  end

  it "calls puts once for each command present" do
    expect {
      help
    }.to output(expected).to_stdout
  end

end

