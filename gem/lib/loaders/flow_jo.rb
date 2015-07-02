require_relative 'flow_jo_xml'

class FlowJoLoader < Magma::Loader
  def load file, patient
    # The flow jo file collects all of the stain gatings and counts for a set of tumor samples
    # from a single patient.
    @flow_jo = FlowJoXml.new file

    # We can take the patient as given:
    @patient  = patient
    #
    # There are four stains:
    # 1. Treg stain
    # 2. Nktb stain
    # 3. Sort stain
    # 4. Dc stain
    #
    # Each stain is associated with a single FCS file. There might be multiple
    # gatings (counts) for a single FCS file, but we can get to this later.
    #
    # Each stain belongs to a sample, which belongs to the patient. So first we must
    # ensure the samples. What we actually HAVE is the tube name 
    # that was used to generate a particular stain. So, we must first go through each of the
    # possible tube names we can generate,
  end

  def dispatch
    create_sample_records
    create_stain_records
  end

  def create_sample_records
    names = all_tubes.map do |tube| sample_name_from(tube.tube_name) end.uniq
    names.each do |name|
      push_record Sample, { sample_name: name, patient_id: @patient.id }
    end
    dispatch_record_set

    @sample_ids = Sample.where(sample_name: names).select_hash(:sample_name, :id)
  end
  
  def sample_name_from tube_name
    case tube_name
    when IPI.sample_name
      return Regexp.last_match[0]
    when /[\W\_](?<code>[TN][0-9])/
      return @patient.ipi_number + "." + Regexp.last_match[:code] 
    when /TUM(?:OR)?[\W\_]*(?<num>)[0-9]/i
      return @patient.ipi_number + ".T" + Regexp.last_match[:num] 
    when /TUM(?:OR)?[\W\_]*/i
      # just guess, least safe
      return @patient.ipi_number + ".T1"
    when /NORM(?:AL)?[\W\_]*(?<num>)[0-9]/i
      return @patient.ipi_number + ".N" + Regexp.last_match[:num] 
    when /NORM(?:AL)?[\W\_]*/i
      # just guess, least safe
      return @patient.ipi_number + ".N1"
    end
  end

  DC_STAIN_MAP = {
    total_acquired_count: "FSC-A, Time subset", #"FSC-A, FSC-W subset", "FSC-A, FSC-H subset",
    live_count: "FSC-A, <Aqua-A> subset",
    cd45_count: "CD45+", #"HLADR -, Lineage -",
    neutrophil_count: "Eosinophils and Neutrophils", 
    hladr_count: "HLADR+",
    lineage_count: "lineage",
    hladr_lineage_negative_count: "HLADR -, Lineage -",
    monocyte_count: "CD16+ monocytes",
    cd11c_count: "CD11c+",
    dc1_count: "BDCA1+ DCs",
    dc2_count: "BDCA3+",
    cd14_neg_tam_count: "CD14- TAMs",
    cd14_pos_tam_count: "CD14+ TAMs",
    peripheral_dc_count: "pDCs",
  }

  TREG_STAIN_MAP = {
    total_acquired_count: "FSC-A, Time subset", 
    #"FSC-A, FSC-W subset", #"FSC-A, FSC-H subset",
    live_count: "live", #"CD45+",
    treg_count: "T-regs",
    teff_count: "T effectors"
    #"HLADR+", #"HLADR-, #CD3e-", #"T-cells", #"CD4+", #"T effectors", #"T-regs", #"CD4-,
    #CD8-", #"CD8+", #"CD45-"
  }

  NKTB_STAIN_MAP = {
    total_acquired_count: "FSC-A, Time subset",
   #"FSC-A, FSC-W subset",
   #"FSC-A, FSC-H subset",
   live_count: "FSC-A, <Aqua-A> subset",
   cd45_count: "CD45+",
   #"HLADR+",
   b_count: "B-cells",
   #"HLADR-, CD3e-",
   nk_count: "NK cells",
   t_count: "T-cells",
   #"CD4+", #"CD4-, CD8-", #"CD8+", #"CD45-",
  }

  SORT_STAIN_MAP = {
    total_acquired_count: "FSC-A, Time subset",
    #"FSC-A, FSC-W subset",
    #"FSC-A, FSC-H subset",
    live_count: "live",
    cd45_count: "CD45+",
    #"lineage",
    lineage_neg_count: "lineage -",
    #"Q1: MHCIIÃ\u0090, CD11b+",
    myeloid_count: "Myeloids",
    #"Q3: MHCII+, CD11bÃ\u0090",
    #"Q4: MHCIIÃ\u0090, CD11bÃ\u0090",
    t_count: "T-cells",
    #"CD45-",
    tumor_count: "EPCAM+",
    #"EPCAM-",
    stroma_count: "Stroma"
  }

  def create_stain_records
    treg_stain_tubes.each do |tube|
      push_record TregStain, stain_document_using(tube,TREG_STAIN_MAP, :treg)
    end
    nktb_stain_tubes.each do |tube|
      push_record NktbStain, stain_document_using(tube,NKTB_STAIN_MAP, :nktb)
    end
    sort_stain_tubes.each do |tube|
      push_record SortStain, stain_document_using(tube,SORT_STAIN_MAP, :sort)
    end
    dc_stain_tubes.each do |tube|
      push_record DcStain, stain_document_using(tube,DC_STAIN_MAP, :dc)
    end
    dispatch_record_set
  end

  def stain_document_using tube, map, stain
    sample_name = sample_name_from(tube.tube_name)
    tube_name = sample_name + "." + stain
    map.map do |name,population|
      { name => tube.populations[population] }
    end.reduce(:merge).merge(
      tube_name: tube_name,
      sample_id: @sample_ids[ sample_name)]
    )
  end

  def all_tubes
    # We could get all_tubes from the group "All samples" in the Jo XML, but this is more better:
    (treg_stain_tubes + 
      nktb_stain_tubes +
      sort_stain_tubes +
      dc_stain_tubes).uniq
  end

  def treg_stain_tubes
    @flow_jo.group("stain 1").sample_refs.map{|sr| @flow_jo.sample(sr)}
  end

  def nktb_stain_tubes
    @flow_jo.group("stain 2").sample_refs.map{|sr| @flow_jo.sample(sr)}
  end

  def sort_stain_tubes
    @flow_jo.group("stain 3").sample_refs.map{|sr| @flow_jo.sample(sr)}
  end

  def dc_stain_tubes
    @flow_jo.group("stain 4").sample_refs.map{|sr| @flow_jo.sample(sr)}
  end
end
