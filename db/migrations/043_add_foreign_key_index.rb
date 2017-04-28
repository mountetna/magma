Sequel.migration do
  change do
    add_index :patients, :experiment_id
    add_index :samples, :patient_id
    add_index :populations, :sample_id
    add_index :patients, :reference_patient_id
    add_index :mfis, :population_id
    add_index :experiments, :project_id
    add_index :rna_seqs, :rna_seq_plate_id
    add_index :fastqs, :rna_seq_id
    add_index :channels, :stain_panel_id
  end
end
