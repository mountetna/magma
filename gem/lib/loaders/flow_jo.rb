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
    create_sample_documents
    delete_existing_populations
    create_population_documents
  end

  def create_sample_documents
    names = all_tubes.map do |tube| sample_name_from(tube.tube_name) end.uniq
    names.each do |name|
      push_record Sample, { sample_name: name, patient: @patient.ipi_number, created_at: DateTime.now, updated_at: DateTime.now }
    end
    dispatch_record_set
  end

  def delete_existing_populations
    # Find all populations for samples with this patient
    mfi_ids = Mfi.join(:populations, id: :population_id)
                 .join(:samples, id: :sample_id)
                 .join(:patients, id: :patient_id)
                 .where('patients.id = ?', @patient.id)
                 .select_map(:mfis__id)
    pop_ids = Population.join(:samples, id: :sample_id)
                        .join(:patients, id: :patient_id)
                        .where('patients.id = ?', @patient.id)
                        .select_map(:populations__id)
    Mfi.where(id: mfi_ids).delete
    Population.where(id: pop_ids).delete
  end
  
  def sample_name_from tube_name
    case tube_name
    when IPI.sample_name
      return Regexp.last_match[0]
    when /[\W\_](?<code>[TN][0-9])/i
      return "#{@patient.ipi_number}.#{ Regexp.last_match[:code] }"
    when /TUM(?:OR)?[\W\_]*(?<num>)[0-9]/i
      return "#{@patient.ipi_number}.T#{ Regexp.last_match[:num] }"
    when /TUM(?:OR)?[\W\_]*/i
      # just guess, least safe
      return "#{@patient.ipi_number}.T1"
    when /NORM(?:AL)?[\W\_]*(?<num>)[0-9]/i
      return "#{@patient.ipi_number}.N#{ Regexp.last_match[:num] }"
    when /NORM(?:AL)?[\W\_]*/i
      # just guess, least safe
      return "#{@patient.ipi_number}.N1"
    else
      raise Magma::LoadFailed.new([ "Could not guess sample name from tube name '#{tube_name}'"])
    end
  end

  def create_population_documents
    treg_stain_tubes.each do |tube|
      create_population_document_using tube, :treg
    end
    nktb_stain_tubes.each do |tube|
      create_population_document_using tube, :nktb
    end
    sort_stain_tubes.each do |tube|
      create_population_document_using tube, :sort
    end
    dc_stain_tubes.each do |tube|
      create_population_document_using tube, :dc
    end
    dispatch_record_set
  end

  def create_population_document_using tube, stain
    sample_name = sample_name_from(tube.tube_name)
    tube_name = "#{sample_name}.#{stain}"
    tube.populations.each do |pop|
      push_record Population, {
        stain: tube_name,
        sample: sample_name_from(tube.tube_name),
        temp_id: temp_id(pop),
        population: temp_id(pop.parent),
        name: pop.name,
        count: pop.count,
        created_at: DateTime.now,
        updated_at: DateTime.now
      }
      pop.statistics.each do |stat|
        push_record Mfi, {
          temp_id: temp_id(stat),
          population: temp_id(pop),
          name: stat.name,
          fluor: stat.fluor,
          value: stat.value,
          created_at: DateTime.now,
          updated_at: DateTime.now
        }
      end
    end
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
