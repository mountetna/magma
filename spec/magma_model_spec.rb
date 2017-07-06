require_relative '../lib/magma'
require 'yaml'

describe Magma::Model do
  describe '.validate' do
    it 'ensures the table exists' do
    end
  end

  describe '.attributes' do
    it 'returns a hash of attributes for this model' do
    end
  end

  describe '.identity' do
    it 'gives the key name for the model\'s identifier' do
    end
    it 'returns id if model has no identifier' do
    end
  end

  describe '.display_attributes' do
    it 'returns the class for a given model name' do
    end
  end

  describe '.order' do
    it 'orders the dataset by column' do
    end
  end

  describe '.has_attribute?' do
    it 'determines whether an attribute exists' do
    end
  end

  context 'Attribute descriptions' do
    describe '.attribute' do
      it 'defines a basic attribute' do
      end
    end
    describe '.identifier' do
      it 'creates an attribute and makes it the identifier' do
      end
    end
    describe '.parent' do
      it 'creates a foreign_key attribute' do
      end
    end
    describe '.link' do
      it 'creates a foreign_key attribute' do
      end
    end
    describe '.document' do
      it 'creates a document attribute' do
      end
    end
    describe '.image' do
      it 'creates an image attribute' do
      end
    end
    describe '.collection' do
      it 'creates a collection attribute' do
      end
    end
  end

  describe '.json_template' do
    it 'returns a json template describing the model' do
    end
  end

  describe '.schema' do
    it 'returns the sequel database schema for this model' do
    end
  end

  describe '.multi_update' do
    it 'updates multiple records at once from an array of json hashes' do
    end
  end

  describe '.update_or_create' do
    it 'updates or creates a record' do
    end
  end

  describe '#identifier' do
    it 'returns the value of the identifier for this record' do
    end
  end

  describe '#run_loaders' do
    it 'runs the specified loader on a particular file' do
    end
  end

  describe '#json_document' do
    it 'returns a json document describing this record' do
    end
  end
end
