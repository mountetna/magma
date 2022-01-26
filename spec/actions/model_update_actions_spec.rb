describe Magma::ModelUpdateActions do
  let(:user) {Etna::User.new({
    email: "outis@mountolympus.org",
    token: "fake"
  })}

  describe '#perform' do
    context 'with invalid action_name' do
      let(:actions) do
        Magma::ModelUpdateActions.build(
          "labors",
          [{
            action_name: "delete_everything",
            model_name: "monster",
            attribute_name: "name",
            description: "The monster's name"
          }],
          user
        )
      end

      it 'produces an error with invalid names' do
        expect(actions.perform).to eq(false)
        expect(actions.errors.first[:message]).to eq("Invalid action type")
      end
    end

    context "with valid actions" do
      let(:model_versions) { nil }
      let(:actions) do
        Magma::ModelUpdateActions.build(
            "labors",
            [
                {
                    action_name: "add_attribute",
                    model_name: "monster",
                    attribute_name: "attribute_one",
                    type: "string"
                },
                {
                    action_name: "add_attribute",
                    model_name: "prize",
                    attribute_name: "attribute_two",
                    type: "integer"
                }
            ],
            user,
            model_versions
        )
      end

      after(:each) do
        # Clear out new test attributes that are cached in memory
        Labors::Monster.attributes.delete(:attribute_one)
        Labors::Prize.attributes.delete(:attribute_two)
        Magma.instance.db[:models].where(project_name: 'labors').update(version: 0)
      end

      before(:each) do
        db = Sequel.connect(Magma.instance.config(:db))
        db[:models].where(project_name: 'labors').update(version: 0)
      end

      context "with model versions specified" do
        let(:model_versions) { {} }

        it "fails for model changes not indicated in model_versions" do
          actions.perform
          expect(actions.errors.map { |e| e[:message] }).to eql([
              "Update for monster found, but no version provided in model_versions.",
              "Update for prize found, but no version provided in model_versions.",
          ])
        end

        context "containing entries for each model change" do
          let(:model_versions) { {"monster" => 5, "prize" => 0, } }

          context "but overlapping transaction is also attempting to update" do
            before(:each) do
              # Sets up a 'race condition' in which, just after reading other folders, but before creating a missing
              # folder, another folder is created by a separate connection (and not visible on the original transaction)
              # that violates the unique constraint.
              allow(actions).to receive(:update_version).and_wrap_original do |m, *args|
                RSpec::Mocks.space.proxy_for(actions).reset
                connection_two = Sequel.connect(Magma.instance.config(:db))
                allow(actions).to receive(:db).and_return(connection_two)
                # Completes the update version while inside a transaction attempting to do the same.
                actions.send(:update_version, 'monster', 5)
                RSpec::Mocks.space.proxy_for(actions).reset
                m.call(*args)
              end
            end

            it 'reports a concurrent modification and rolls back last to write transaction' do
              actions.perform
              expect(actions.errors.map { |e| e[:message] }).to eql(["Concurrent modification"])

              expect(Labors::Monster.dataset.columns!).to_not include(:attribute_one)
              expect(Labors::Prize.dataset.columns!).to_not include(:attribute_two)
            end
          end

          context "but the versions are out of date" do
            let(:model_versions) { {"monster" => -1, "prize" => 0, } }

            it "fails for model changes not indicated in model_versions" do
              actions.perform
              expect(actions.errors.map { |e| e[:message] }).to eql([
                  "Update for monster out of date. Current version is 0",
              ])
            end
          end

          it "succeeds in applying the changes" do
            actions.perform
            expect(actions.errors).to eql([])

            expect(Labors::Monster.dataset.columns!).to include(:attribute_one)
            expect(Labors::Monster.attributes[:attribute_one]).to be_a(Magma::StringAttribute)

            expect(Labors::Prize.dataset.columns!).to include(:attribute_two)
            expect(Labors::Prize.attributes[:attribute_two]).to be_a(Magma::IntegerAttribute)
          end

          it "updates the model versions" do
            expect do
              actions.perform
            end.to change {
              Magma.instance.db[:models].where(project_name: 'labors', model_name: ['monster', 'prize']).sort_by { |r| r[:model_name] }.map { |r| r[:version] }
            }.to([6, 1])
          end
        end
      end

      it "persists action changes in both the db and in memory" do
        expect(actions.perform).to eq(true)

        expect(Labors::Monster.dataset.columns!).to include(:attribute_one)
        expect(Labors::Monster.attributes[:attribute_one]).to be_a(Magma::StringAttribute)

        expect(Labors::Prize.dataset.columns!).to include(:attribute_two)
        expect(Labors::Prize.attributes[:attribute_two]).to be_a(Magma::IntegerAttribute)
      end
    end

    context "when an action fails" do
      let(:actions) do
        Magma::ModelUpdateActions.build(
          "labors",
          [
            {
              action_name: "add_attribute",
              model_name: "monster",
              attribute_name: "new_attribute",
              type: "string"
            },
            {
              action_name: "update_attribute",
              model_name: "monster",
              attribute_name: "species",
              validation: "invalid"
            }
          ],
          user
        )
      end

      it "returns false and doesn't persist any action changes" do
        expect(actions.perform).to eq(false)
        expect(actions.errors).not_to be_empty

        expect(Magma::Attribute["labors", "monster", "new_attribute"]).to be_nil
        expect(Labors::Monster.dataset.columns!).not_to include(:new_attribute)
        expect(Labors::Monster.attributes.keys).not_to include(:new_attribute)
        expect(Labors::Monster.attributes[:species].validation).not_to eq("validation")
      end
    end
  end
end
