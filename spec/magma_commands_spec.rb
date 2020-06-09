describe 'Magma Commands' do
  describe Magma::LoadProject do
    let(:json_file) { './spec/fixtures/template.json' }

    subject(:load_project) { described_class.new.execute('project_name', json_file) }

    let(:attributes) { Magma.instance.db[:attributes] }

    it 'loads attributes into the database' do
      file = File.open(json_file).read
      json_attributes = JSON.parse(file)["models"]["monster"]["template"]["attributes"]
      model_json_template = JSON.parse(Labors::Monster.json_template.to_json)["attributes"]
      expect {
        load_project
      }.to change { attributes.count }.by(8)
      expect(json_attributes).to eq(model_json_template)
    end
  end

  let(:magma_instance) { double('Magma') }

  describe Magma::Help do
    subject(:help) { described_class.new.execute }

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

  describe Magma::Migrate do
    subject(:migrate) { described_class.new.execute(version) }
    let(:directory) { "./spec/labors/migrations" }
    let(:table) {"schema_info_spec_labors" }

    before do
      Sequel.extension(:migration)
      allow(Magma.instance).to receive(:db).and_return(magma_instance)
    end

    describe 'when a version is specified' do
      let(:version) { '001' }

      before do
        allow(Sequel::Migrator).to receive(:run).with(magma_instance, directory, table: table, target: version.to_i).and_return(true)
      end

      it 'calls run with a version number' do
        migrate

        expect(Sequel::Migrator)
          .to have_received(:run)
          .with(magma_instance, directory, table: table, target: version.to_i)
          .once
      end
    end

    describe 'without a version specified' do
      let(:version) { nil }

      before do
        allow(Sequel::Migrator).to receive(:run).with(magma_instance, directory, table: table).and_return(true)
      end

      it 'calls run without a version number' do
        migrate

        expect(Sequel::Migrator)
          .to have_received(:run)
          .with(magma_instance, directory, table: table)
          .once
      end
    end
  end

  describe Magma::GlobalMigrate do
    subject(:global_migrate) { described_class.new.execute(version) }
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

  describe Magma::Plan do
    subject(:plan) { described_class.new.execute(project_name) }

    let(:project_double) { double('project', migrations: 'migrations') }
    let(:expected) do 
      "Sequel.migration do\n  change do\nmigrations\n  end\nend\n"
    end

    before { allow(Magma).to receive(:instance).and_return(magma_instance) }

    describe 'with a project_name present' do
      let(:project_name) { 'project_name' }


      describe 'when the project exists' do
        before do 
          allow(magma_instance).to receive(:get_project).with(project_name).and_return(project_double)
        end

        it 'outputs project migrations' do
          expect {
            plan
          }.to output(expected).to_stdout
        end
      end

      describe 'when the project does not exist' do
        before do 
          allow(magma_instance).to receive(:get_project).with(project_name).and_return(nil) 
        end

        it 'raises ArugmentError' do
          expect {
            plan
          }.to raise_error(ArgumentError)
        end
      end
    end

    describe 'without a project_name present' do
      let(:project_name) { nil }
      let(:project_hash) { { project: project_double } }

      before do 
        allow(magma_instance).to receive(:magma_projects).and_return(project_hash)
      end

      it 'outputs project migrations' do
        expect { plan }.to output(expected).to_stdout
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

  describe Magma::CreateDb do
    let(:project_name) { 'project_name' }
    let(:createdb_instance) { described_class.new }
    let(:config_double) { double('config') } 
    let(:expected) { "Database is setup. Please run `bin/magma migrate project_name`.\n" }
    subject(:create_db) { createdb_instance.execute(project_name) }

    before do
      allow(Magma).to receive(:instance).and_return(magma_instance)
      allow(magma_instance).to receive(:config).with(:db).and_return({ database: 'database' })
    end

    describe 'with @no_db = true' do

      before do
        allow(magma_instance).to receive(:setup_db).and_raise Sequel::DatabaseConnectionError
        allow(magma_instance).to receive(:configure).with(config_double)
        createdb_instance.setup(config_double)
        allow(createdb_instance).to receive(:db_namespace?).and_return(true)
        allow(createdb_instance).to receive(:create_db)
      end

      it 'calls create_db' do
        expect {
          create_db
        }.to output(expected).to_stdout
        
        expect(createdb_instance).to have_received(:create_db).once
      end
    end

    describe 'with db_namespace? = true' do
      let(:db_double) { double('db') }

      before do
        allow(magma_instance).to receive(:setup_db)
        allow(magma_instance).to receive(:configure).with(config_double)
        allow(createdb_instance).to receive(:db_namespace?).and_return(false)
        createdb_instance.setup(config_double)
        allow(magma_instance).to receive(:db).and_return(db_double)
        allow(db_double).to receive(:run).with("CREATE SCHEMA project_name")
        allow(createdb_instance).to receive(:create_schema)
      end

      it 'calls create_schema' do
        expect {
          create_db
        }.to output(expected).to_stdout

        expect(createdb_instance).to have_received(:create_schema).once
      end
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
