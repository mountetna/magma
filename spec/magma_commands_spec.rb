describe 'Magma Commands' do
  let(:magma_instance) { double('Magma') }

  describe Magma::Migrate do
    subject(:global_migrate) { described_class.new.execute(version: version) }
    let(:directory) { "db/migrations" }
    let(:table) {"schema_info_spec_labors" }

    before do
      Sequel.extension(:migration)
      allow(Magma.instance).to receive(:db).and_return(magma_instance)
    end

    describe 'when a version is specified' do
      let(:version) { '001' }

      before do
        allow(Sequel::Migrator).to receive(:run).with(magma_instance, directory, target: version.to_i).and_return(true)
      end

      it 'calls run with a version number' do
        global_migrate

        expect(Sequel::Migrator)
          .to have_received(:run)
          .with(magma_instance, directory, target: version.to_i)
          .once
      end
    end

    describe 'without a version specified' do
      let(:version) { nil }

      before do
        allow(Sequel::Migrator).to receive(:run).with(magma_instance, directory).and_return(true)
      end

      it 'calls run without a version number' do
        global_migrate

        expect(Sequel::Migrator)
          .to have_received(:run)
          .with(magma_instance, directory)
          .once
      end
    end
  end

  describe Magma::Console do
    subject(:console) { described_class.new.execute }
    before do
      require 'irb'
      allow(ARGV).to receive(:clear)
      allow(IRB).to receive(:start)
    end

    it 'calls ARGV and IRB' do
      console

      expect(ARGV).to have_received(:clear).once
      expect(IRB).to have_received(:start).once
    end
  end

  describe Magma::Unload do
    let(:project_name) { 'project_name' }
    let(:model_name) { 'model_name' }
    let(:tsv_writer_instance) { double('tsv_writer') }
    let(:model_double) { double('model') }
    let(:retrieval_double) { double('retrieval') }
    let(:payload_double) { double('payload') }

    subject(:unload) { described_class.new.execute(project_name, model_name) }

    before do
      allow(Magma).to receive(:instance).and_return(magma_instance)
      allow(magma_instance).to receive(:get_model).with(project_name, model_name).and_return(model_double)
      allow(Magma::Retrieval).to receive(:new).with(model_double, 'all', 'all', page: 1, page_size: 100_000).and_return(retrieval_double)
      allow(Magma::Payload).to receive(:new).and_return(payload_double)
      allow(Magma::TSVWriter).to receive(:new).with(model_double, retrieval_double, payload_double).and_return(tsv_writer_instance)
      allow(tsv_writer_instance).to receive(:write_tsv)
    end

    it 'calls TSVWriter.new once' do
      unload

      expect(tsv_writer_instance).to have_received(:write_tsv).once
    end
  end

 describe Magma::Load do
    subject(:loader_execute) { described_class.new.execute('loader name', 'args') }

    let(:loader) { double('loader', loader_name: 'loader name', description: 'description') }
    let(:loaders_array) { [loader] }
    let(:expected) { 'yup' }

    before do
      allow(Magma).to receive(:instance).and_return(magma_instance)
      allow(magma_instance).to receive(:find_descendents).with(Magma::Loader).and_return(loaders_array)
      allow(loader).to receive(:new).and_return(loader)
      allow(loader).to receive(:load).with('args')
      allow(loader).to receive(:dispatch)
    end

    it 'displays available loaders' do
      loader_execute

      expect(loader).to have_received(:dispatch).once
    end
  end
end
