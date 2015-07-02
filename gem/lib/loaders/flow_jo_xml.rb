require 'nokogiri'

class FlowJoXml
  class Population
    attr_reader :xml
    def initialize xml
      @xml = xml
    end

    def name
      @name ||= @xml.attr('name')
    end

    def count
      @count ||= @xml.attr('count').to_i
    end

    def to_hash
      { name => count }
    end
  end
  class Sample
    attr_reader :xml
    def initialize xml
      @xml = xml
    end

    def tube_name
      @tube_name ||= @xml.css('Keyword[name="TUBE NAME"]').first.attr("value")
    end

    def populations
      @populations ||= @xml.css('Population').map{|p| Population.new(p).to_hash;}.reduce :merge
    end
  end
  class Group
    attr_reader :xml
    def initialize xml
      @xml = xml
    end

    def sample_refs
      @xml.css('SampleRef').map{|sr| sr.attr("sampleID") }
    end
  end

  def initialize file
    @xml = Nokogiri::XML(file.read)
    @samples = {}
    @groups = {}
  end

  def sample id
    @samples[id] ||= FlowJoXml::Sample.new(@xml.css("Sample[sampleID=\"#{id}\"]"))
  end

  def group name
    @groups[name] ||= FlowJoXml::Group.new(@xml.css("GroupNode[name=\"#{name}\"]"))
  end
end
