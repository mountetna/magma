module Ipi
  class Sample < Magma::Model
    class Headshot < Magma::Metric
      category :processing

      def test
        return success if @record.headshot.file
        failure "Could not find a headshot."
      end
    end
    class TumorType < Magma::Metric
      category :processing

      def test
        return success if @record.tumor_type
        failure "Tumor type is not set."
      end
    end
    class FlowjoXml < Magma::Metric
      category :flow

      def test
        return success if @record.patient && @record.patient.flojo_file.file
        failure "A FlowJo XML file (.WSP) has not been loaded for this patient."
      end
    end
    class FcsFiles < Magma::Metric
      category :flow
  
      def check_file stain
        @missing_files.push stain if !@record.send(:"#{stain}_file").file
      end
  
      def test
        @missing_files = []
  
        [ "treg", "nktb", "sort", "dc", "innate" ].each do |stain|
          check_file stain
        end
  
        if @missing_files.empty?
          return success
        else
          detail "Missing files", @missing_files
          failure "Some FCS files were missing."
        end
      end
    end
    class Populations < Magma::Metric
      category :flow
  
      def check_population stain
        @missing_stains.push stain unless @record.population.any? do |pop|
          pop.stain == stain
        end
      end
  
      def test
        @missing_stains = []
        [ "treg", "nktb", "sort", "dc" ].each do |stain|
          check_population stain
        end
  
        if @missing_stains.empty?
          return success
        else
          detail "Missing stains", @missing_stains
          failure "Population counts are absent for some stains."
        end
      end
    end
    class ValidTree < Magma::Metric
      category :flow
  
      def pop_key_set pops
        Set.new(pops.map do |pop|
          [ pop.stain, pop.name, pop.ancestry ]
        end)
      end
  
      def test
        patient = @record.patient
  
        return invalid("No reference patient") unless reference_patient = patient.reference_patient
  
        reference_sample = reference_patient.sample.first
  
        return success if !reference_sample
  
        sample_stains = @record.population.map(&:stain).uniq
  
        ref_key_set = pop_key_set reference_sample.population
        sam_key_set = pop_key_set @record.population
  
        return invalid("No sample populations") if sample_stains.empty? && !ref_key_set.empty?
  
        extra_pops = @record.population.reject do |pop|
          ref_key_set.include? [ pop.stain, pop.name, pop.ancestry ]
        end
  
        missing_pops = reference_sample.population.select do |pop|
          sample_stains.include?(pop.stain) && !sam_key_set.include?([ pop.stain, pop.name, pop.ancestry ])
        end
  
        if !missing_pops.empty?
          detail("Missing Population Ancestors", missing_pops.map do |pop|
             pop.ancestry
          end.uniq)
  
  
          detail("Missing Populations", missing_pops.map do |pop|
            "#{pop.stain} : #{pop.name} > #{pop.ancestry}"
          end)
        end
  
        if !extra_pops.empty?
          detail("Missing Extra Population Ancestors", missing_pops.map do |pop|
             pop.ancestry
          end.uniq)
  
          detail("Extra Populations", extra_pops.map do |pop|
            "#{pop.stain} : #{pop.name} > #{pop.ancestry}"
          end)
        end
  
        if missing_pops.empty?
          success
        else
          failure "Required reference populations are missing."
        end
      end
    end
    class Rna < Magma::Metric
      category :rna
  
      def check_compartment comp
        @missing_compartments.push comp unless @record.rna_seq.any?  do |rna|
          rna.compartment == comp
        end
      end
  
      def test
        @missing_compartments = []
  
        [ "tcell", "treg", "stroma", "live", "myeloid", "tumor" ].each do |comp|
          check_compartment comp
        end
  
        if @missing_compartments.empty?
          success
        else
          detail "Missing compartments", @missing_compartments
          failure "Could not find an rna_seq for some compartments."
        end
      end
    end
  
    class Gexp < Magma::Metric
      category :rna
  
      def check_compartment comp
        @missing_compartments.push comp unless Ipi::GeneExp.join(Sequel[:ipi][:rna_seqs], Sequel[:ipi][:gene_exps][:rna_seq_id] => Sequel[:ipi][:rna_seqs][:id])
          .join(Sequel[:ipi][:samples], Sequel[:ipi][:samples][:id] => Sequel[:ipi][:rna_seqs][:sample_id])
          .where(Sequel[:ipi][:rna_seqs][:compartment] => comp)
          .where(sample_name: @record.sample_name).count > 1
      end
  
      def test
        @missing_compartments = []
  
        [ "tcell", "treg", "stroma", "live", "myeloid", "tumor" ].each do |comp|
          check_compartment comp
        end
  
        if @missing_compartments.empty?
          success
        else
          detail "Missing compartments", @missing_compartments
          failure "Could not find gene_exp for some compartments."
        end
      end
    end
  end
end
