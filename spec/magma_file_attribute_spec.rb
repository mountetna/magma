require_relative '../lib/magma'

describe Magma::FileAttribute do
  it 'stores a JSON database type' do
    file_attribute = Labors::Monster.attributes[:stats]

    expect(file_attribute.database_type).to eq(:json)
  end

  describe ".revision_to_loader" do
    let(:file_attribute) { Labors::Monster.attributes[:stats] }
    it 'returns entry when given valid path' do
        expect(file_attribute.revision_to_loader("Nemean Lion", {
            path: "metis://labors/Nemean Lion/lion-stats.txt"
        })).to eq([
            :stats,
            {
                "filename": "monster-Nemean Lion-stats.txt",
                "original_filename": nil,
                "location": "metis://labors/Nemean Lion/lion-stats.txt"
            }
        ])
    end

    it 'returns entry for ::blank path' do
        expect(file_attribute.revision_to_loader("Nemean Lion", {
            path: "::blank"
        })).to eq([
            :stats,
            {
                "filename": "::blank",
                "original_filename": "::blank",
                "location": "::blank"
            }
        ])
    end

    it 'returns nil entry for nil path' do
        expect(file_attribute.revision_to_loader("Nemean Lion", {
            path: nil
        })).to eq([
            :stats,
            {
                "filename": nil,
                "original_filename": nil,
                "location": nil
            }
        ])
    end

    it 'returns nil for ::temp path' do
        expect(file_attribute.revision_to_loader("Nemean Lion", {
            path: "::temp"
        })).to eq(nil)
    end
  end

  describe ".revision_to_payload" do
    let(:file_attribute) { Labors::Monster.attributes[:stats] }
    let(:user) { Etna::User.new(email: "heracles@mountolympus.org", first: "Heracles", last: "of Thebes") }
    it 'returns full payload when given valid path' do
        payload = file_attribute.revision_to_payload("Nemean Lion", {
            path: "metis://labors/Nemean Lion/lion-stats.txt"
        }, user)
        
        expect(payload[0]).to eq(:stats)
        expect(payload[1][:path]).to eq("monster-Nemean Lion-stats.txt")
        expect(payload[1][:original_filename]).to eq(nil)
        expect(payload[1][:url].is_a? URI).to eq(true)
        expect(payload[1][:url].query.include? "X-Etna-Signature=").to eq(true)
    end

    it 'returns simple path for ::blank path' do
        expect(file_attribute.revision_to_payload("Nemean Lion", {
            path: "::blank"
        }, user)).to eq([
            :stats,
            {
                path: "::blank"
            }
        ])
    end

    it 'returns nil entry for nil path' do
        expect(file_attribute.revision_to_payload("Nemean Lion", {
            path: nil
        }, user)).to eq([
            :stats, nil
        ])
    end

    it 'returns signed upload Metis path for ::temp path' do
        payload = file_attribute.revision_to_payload("Nemean Lion", {
            path: "::temp"
        }, user)
        
        expect(payload[0]).to eq(:stats)
        expect(payload[1][:path].is_a? URI).to eq(true)
        expect(payload[1][:path].query.include? "X-Etna-Signature=").to eq(true)
    end
  end

  describe ".query_to_payload" do
    let(:file_attribute) { Labors::Monster.attributes[:stats] }
    
    it 'returns nil if no data passed in' do
        expect(file_attribute.query_to_payload(nil)).to eq(nil)
    end

    it 'returns nil if no filename in the data' do
        expect(file_attribute.query_to_payload({
            key: 'value'
        })).to eq(nil)
    end

    it 'returns full query when given valid filename' do
        query = file_attribute.query_to_payload({
            filename: "monster-Nemean Lion-stats.txt"
        })
        
        expect(query[:path]).to eq("monster-Nemean Lion-stats.txt")
        expect(query[:original_filename]).to eq(nil)
        expect(query[:url].is_a? URI).to eq(true)
        expect(query[:url].query.include? "X-Etna-Signature=").to eq(true)
    end

    it 'returns simple query for ::blank filename' do
        expect(file_attribute.query_to_payload({
            filename: "::blank"
        })).to eq({
                path: "::blank"
            }
        )
    end

    it 'returns nil for nil filename' do
        expect(file_attribute.query_to_payload({
            filename: nil
        })).to eq(nil)
    end

    it 'returns ::temp query for ::temp filename' do
        expect(file_attribute.query_to_payload({
            filename: "::temp"
        })).to eq({
            path: "::temp"
        })
    end
  end
end
