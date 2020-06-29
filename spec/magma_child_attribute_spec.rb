require_relative '../lib/magma'

describe Magma::ChildAttribute do
  describe '.update' do
    let(:child_attribute) { Magma.instance.magma_projects[:labors].models[:labor].attributes[:monster] }
    let(:record) { double('record', id: 1) }
    let(:link) { double('link') }
    let(:link_model) { child_attribute.link_model }

    before do
      allow(link_model).to receive(:update_or_create).with(link_model.identity => link)
        .and_return true
    end

    it 'calls update or create on the link_model' do
      child_attribute.update(record, link)

      expect(link_model).to have_received(:update_or_create).once
    end
  end
end
