require 'nokogiri'

class FlowJoXml
  module CensorInspect
    def inspect
      "#<#{self.class}:0x#{object_id} #{
        instance_variables.map do |var| 
          next if var == :"@xml"
          "#{var}=#{instance_variable_get(var).inspect}"
        end.compact.join(", ")
        }>"
    end
  end
  include CensorInspect
  class Statistic
    include CensorInspect
    attr_reader :xml
    def initialize xml
      @xml = xml
    end
    def name
      @name ||= @xml.attr('stain')
    end

    def value
      @value ||= @xml.attr('value').to_f
    end

    def fluor
      @fluor ||= @xml.attr('name')
    end
  end
  class Population
    include CensorInspect
    attr_reader :xml, :parent
    def initialize xml, parent
      @xml = xml
      @parent = parent
    end

    def name
      @name ||= @xml.attr('name')
    end

    def count
      @count ||= @xml.attr('count').to_i
    end

    def statistics
      @statistics ||= @xml.css('> Statistic').map do |stat|
        Statistic.new(stat)
      end
    end

    def to_hash
      { name => count }
    end
  end
  class Sample
    include CensorInspect
    attr_reader :xml
    def initialize xml
      @xml = xml
    end

    def tube_name
      @tube_name ||= @xml.css('Keyword[name="TUBE NAME"]').first.attr("value")
    end

    def populations
      @populations ||= populations_for_node(@xml.css('SampleNode > Population').first)
    end

    def populations_for_node node, parent=nil
      return [] unless node
      pop = Population.new(node, parent)
      children = node.css('> Population').map do |child|
        populations_for_node(child, pop)
      end
      [ pop, children ].flatten
    end
  end
  class Group
    include CensorInspect
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

  class NameSearch
    def named_like(node_set, att, txt)
      node_set.find_all do |node| 
        node[att] =~ /#{txt}/i
      end
    end
  end

  def sample id
    @samples[id] ||= FlowJoXml::Sample.new(@xml.css("Sample:named_like(\"sampleID\",\"#{id}\")",FlowJoXml::NameSearch.new))
  end

  def group name
    @groups[name] ||= FlowJoXml::Group.new(@xml.css("GroupNode:named_like(\"name\",\"#{name}\")",FlowJoXml::NameSearch.new))
  end
end
