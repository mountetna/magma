describe Magma::Migration do
  context 'empty migrations' do
    it 'does nothing if there is no change' do
      migration = Labors::Project.migration

      expect(migration).to be_empty
      expect(migration.to_s).to eq('')
    end
  end

  context 'creation migrations' do
    after(:each) do
      Labors.send(:remove_const, :Olympian)
      project = Magma.instance.get_project(:labors)
      project.models.delete(:olympian)
    end

    it 'suggests a creation migration for identifiers' do
      module Labors
        class Olympian < Magma::Model
          identifier :name, type: String
        end
      end
      migration = Labors::Olympian.migration
      expect(migration.to_s).to eq <<EOT.chomp
    create_table(Sequel[:labors][:olympians]) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      String :name
      unique :name
    end
EOT
    end

    it 'suggests a creation migration for attributes' do
      module Labors
        class Olympian < Magma::Model
          integer :number
        end
      end
      migration = Labors::Olympian.migration
      expect(migration.to_s).to eq <<EOT.chomp
    create_table(Sequel[:labors][:olympians]) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      Integer :number
    end
EOT
    end

    it 'suggests nothing in the creation for a table or collection attribute' do
      module Labors
        class Olympian < Magma::Model
          collection :victim
          table :prize
        end
      end
      migration = Labors::Olympian.migration
      expect(migration.to_s).to eq <<EOT.chomp
    create_table(Sequel[:labors][:olympians]) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
    end
EOT
    end

    it 'suggests a creation migration for json attributes' do
      module Labors
        class Olympian < Magma::Model
          match :prayers
        end
      end
      migration = Labors::Olympian.migration
      expect(migration.to_s).to eq <<EOT.chomp
    create_table(Sequel[:labors][:olympians]) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      json :prayers
    end
EOT
    end

    it 'suggests a creation migration for link attributes' do
      module Labors
        class Olympian < Magma::Model
          parent :project

          link :monster
        end
      end
      migration = Labors::Olympian.migration
      expect(migration.to_s).to eq <<EOT.chomp
    create_table(Sequel[:labors][:olympians]) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      foreign_key :project_id, Sequel[:labors][:projects]
      index :project_id
      foreign_key :monster_id, Sequel[:labors][:monsters]
      index :monster_id
    end
EOT
    end
  end

  context 'update migrations' do
    def remove_attribute(model, attribute)
      model.attributes.delete(attribute)
      model.instance_variable_set("@identity",nil) if model.identity.column_name.to_sym == attribute
    end

    it 'suggests an update migration for identifiers' do
      module Labors
        class Prize < Magma::Model
          identifier :prize_code, type: String
        end
      end
      migration = Labors::Prize.migration
      expect(migration.to_s).to eq <<EOT.chomp
    alter_table(Sequel[:labors][:prizes]) do
      add_column :prize_code, String
      add_unique_constraint :prize_code
    end
EOT
      remove_attribute(Labors::Prize, :prize_code)
      Labors::Prize.order()
    end

    it 'suggests an update migration for attributes' do
      module Labors
        class Prize < Magma::Model
          float :weight
        end
      end
      migration = Labors::Prize.migration
      expect(migration.to_s).to eq <<EOT.chomp
    alter_table(Sequel[:labors][:prizes]) do
      add_column :weight, Float
    end
EOT
      remove_attribute(Labors::Prize, :weight)
    end

    it 'suggests an update migration for json attributes' do
      module Labors
        class Prize < Magma::Model
          match :dimensions
        end
      end
      migration = Labors::Prize.migration
      expect(migration.to_s).to eq <<EOT.chomp
    alter_table(Sequel[:labors][:prizes]) do
      add_column :dimensions, :json
    end
EOT
      remove_attribute(Labors::Prize, :dimensions)
    end

    it 'suggests an update migration for link attributes' do
      module Labors
        class Prize < Magma::Model
          link :monster
        end
      end
      migration = Labors::Prize.migration
      expect(migration.to_s).to eq <<EOT.chomp
    alter_table(Sequel[:labors][:prizes]) do
      add_foreign_key :monster_id, Sequel[:labors][:monsters]
      add_index :monster_id
    end
EOT
      remove_attribute(Labors::Prize, :monster)
    end

    it 'removes attributes' do
      worth = Labors::Prize.attributes[:worth]
      remove_attribute(Labors::Prize,:worth)

      migration = Labors::Prize.migration
      expect(migration.to_s).to eq <<EOT.chomp
    alter_table(Sequel[:labors][:prizes]) do
      drop_column :#{worth.column_name}
    end
EOT
      Labors::Prize.attributes[:worth] = worth
    end

    it 'makes no changes when removing child, collection or table attributes' do
      monster = Labors::Labor.attributes[:monster]
      prize = Labors::Labor.attributes[:prize]
      victim = Labors::Monster.attributes[:victim]
      remove_attribute(Labors::Labor,:monster)
      remove_attribute(Labors::Labor,:prize)
      remove_attribute(Labors::Monster,:victim)

      expect(Labors::Labor.migration).to be_empty
      expect(Labors::Monster.migration).to be_empty

      Labors::Labor.attributes[:monster] = monster
      Labors::Labor.attributes[:prize] = prize
      Labors::Monster.attributes[:victim] = victim
    end

    it 'makes multiple changes at once' do
      worth = Labors::Prize.attributes[:worth]
      remove_attribute(Labors::Prize,:worth)
      module Labors
        class Prize < Magma::Model
          float :weight
        end
      end

      migration = Labors::Prize.migration
      expect(migration.to_s).to eq <<EOT.chomp
    alter_table(Sequel[:labors][:prizes]) do
      add_column :weight, Float
      drop_column :#{worth.column_name}
    end
EOT
      remove_attribute(Labors::Prize, :weight)
      Labors::Prize.attributes[:worth] = worth
    end

    context 'changes column types' do
      it 'for simple types' do
        original_attribute = Labors::Prize.attributes.delete(:worth)
        Labors::Prize.attributes[:worth] = Magma::Model.float(
          :worth,
          column_name: original_attribute.column_name
        )

        migration = Labors::Prize.migration
        expect(migration.to_s).to eq <<EOT.chomp
    alter_table(Sequel[:labors][:prizes]) do
      set_column_type :#{original_attribute.column_name}, Float
    end
EOT

        Labors::Prize.attributes[:worth] = original_attribute
      end

      it 'for symbol types' do
        original_attribute = Labors::Prize.attributes.delete(:worth)
        Labors::Prize.attributes[:worth] = Magma::Model.image(
          :worth,
          column_name: original_attribute.column_name
        )

        migration = Labors::Prize.migration
        expect(migration.to_s).to eq <<EOT.chomp
    alter_table(Sequel[:labors][:prizes]) do
      set_column_type :#{original_attribute.column_name}, :json, using: 'worth::json'
    end
EOT
        Labors::Prize.attributes[:worth] = original_attribute
      end
    end
  end
end
