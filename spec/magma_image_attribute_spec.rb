# This should behave exactly like the File Attribute....
# Except for thumbnails? May handle that on the Metis / Timur side.
require_relative '../lib/magma'

describe Magma::ImageAttribute do
  it 'stores a JSON database type' do
    image_attribute = Magma.instance.magma_projects[:labors].models[:monster].attributes[:selfie]

    expect(image_attribute.database_type).to eq(:json)
  end

  describe ".revision_to_loader" do
    let(:image_attribute) { Magma.instance.magma_projects[:labors].models[:monster].attributes[:selfie] }
    it 'returns entry when given valid path' do
        expect(image_attribute.revision_to_loader("Nemean Lion", {
            path: "metis://labors/Nemean Lion/lion-selfie.txt"
        })).to eq([
            :selfie,
            {
                "filename": "monster-Nemean Lion-selfie.txt",
                "original_filename": nil,
                "location": "metis://labors/Nemean Lion/lion-selfie.txt"
            }
        ])
    end

    it 'returns entry for ::blank path' do
        expect(image_attribute.revision_to_loader("Nemean Lion", {
            path: "::blank"
        })).to eq([
            :selfie,
            {
                "filename": "::blank",
                "original_filename": "::blank",
                "location": "::blank"
            }
        ])
    end

    it 'returns nil entry for nil path' do
        expect(image_attribute.revision_to_loader("Nemean Lion", {
            path: nil
        })).to eq([
            :selfie,
            {
                "filename": nil,
                "original_filename": nil,
                "location": nil
            }
        ])
    end

    it 'returns nil for ::temp path' do
        expect(image_attribute.revision_to_loader("Nemean Lion", {
            path: "::temp"
        })).to eq(nil)
    end
  end

  describe ".revision_to_payload" do
    let(:image_attribute) { Magma.instance.magma_projects[:labors].models[:monster].attributes[:selfie] }
    let(:user) { Etna::User.new(email: "heracles@mountolympus.org", first: "Heracles", last: "of Thebes") }
    it 'returns full payload when given valid path' do
        payload = image_attribute.revision_to_payload("Nemean Lion", {
            path: "metis://labors/Nemean Lion/lion-selfie.txt"
        }, user)
        
        expect(payload[0]).to eq(:selfie)
        expect(payload[1][:path]).to eq("monster-Nemean Lion-selfie.txt")
        expect(payload[1][:original_filename]).to eq(nil)
        expect(payload[1][:url].is_a? URI).to eq(true)
        expect(payload[1][:url].query.include? "X-Etna-Signature=").to eq(true)
    end

    it 'returns simple path for ::blank path' do
        expect(image_attribute.revision_to_payload("Nemean Lion", {
            path: "::blank"
        }, user)).to eq([
            :selfie,
            {
                path: "::blank"
            }
        ])
    end

    it 'returns nil entry for nil path' do
        expect(image_attribute.revision_to_payload("Nemean Lion", {
            path: nil
        }, user)).to eq([
            :selfie, nil
        ])
    end

    it 'returns signed upload Metis path for ::temp path' do
        payload = image_attribute.revision_to_payload("Nemean Lion", {
            path: "::temp"
        }, user)
        
        expect(payload[0]).to eq(:selfie)
        expect(payload[1][:path].is_a? URI).to eq(true)
        expect(payload[1][:path].query.include? "X-Etna-Signature=").to eq(true)
    end
  end

  describe ".query_to_payload" do
    let(:image_attribute) { Magma.instance.magma_projects[:labors].models[:monster].attributes[:selfie] }
    
    it 'returns nil if no data passed in' do
        expect(image_attribute.query_to_payload(nil)).to eq(nil)
    end

    it 'returns nil if no filename in the data' do
        expect(image_attribute.query_to_payload({
            key: 'value'
        })).to eq(nil)
    end

    it 'returns full query when given valid filename' do
        query = image_attribute.query_to_payload({
            filename: "monster-Nemean Lion-selfie.txt"
        })
        
        expect(query[:path]).to eq("monster-Nemean Lion-selfie.txt")
        expect(query[:original_filename]).to eq(nil)
        expect(query[:url].is_a? URI).to eq(true)
        expect(query[:url].query.include? "X-Etna-Signature=").to eq(true)
    end

    it 'returns simple query for ::blank filename' do
        expect(image_attribute.query_to_payload({
            filename: "::blank"
        })).to eq({
                path: "::blank"
            }
        )
    end

    it 'returns nil for nil filename' do
        expect(image_attribute.query_to_payload({
            filename: nil
        })).to eq(nil)
    end

    it 'returns ::temp query for ::temp filename' do
        expect(image_attribute.query_to_payload({
            filename: "::temp"
        })).to eq({
            path: "::temp"
        })
    end
  end
end
