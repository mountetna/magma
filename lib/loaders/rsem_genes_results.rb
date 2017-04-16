require 'hash_table'

class RsemGenesResults < HashTable
  class RsemGene < HashTable::Row
    def has_good_gene_name?
      gene_id !~ /(^sno|^A[DPCLEF][0-9]{3}|^C.*orf|-)/
    end
  end

  types tpm: :float, expected_count: :float
end

class RsemGenesResultsLoader < Magma::Loader
  def load file_name, rna_seq
    @results = RsemGenesResults.new.parse file_name

    @rna_seq  = rna_seq
  end

  def dispatch
    delete_existing_gene_exp_documents
    create_gene_exp_documents
  end

  def create_gene_exp_documents
    @results.select(&:has_good_gene_name?).each do |gene|
      push_record GeneExp, {
        rna_seq: @rna_seq.tube_name,
        gene_name: gene.gene_id,
        read_counts: gene.expected_count,
        expression: gene.tpm,
        created_at: DateTime.now,
        updated_at: DateTime.now 
      }
    end
    dispatch_record_set
  end

  def delete_existing_gene_exp_documents
    # Find all populations for samples with this patient
    GeneExp.where(rna_seq_id: @rna_seq.id).delete
  end
end
