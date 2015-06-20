Sequel.migration do
  change do
    alter_table(:samples) do
      add_column :notes, String
      add_column :processed, TrueClass
      drop_column :experiment_id
      drop_column :flojo_file
    end
    alter_table(:rna_seqs) do
      drop_column :rna_seq_batch_id
    end
    create_table(:imagings) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      foreign_key :sample_id, :samples
      String :image_name
      unique :image_name
      Integer :cd45_count
      Integer :cd4_count
      Integer :cd3_count
      String :tiff_file
    end
    create_table(:documents) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      String :name
      unique :name
      foreign_key :project_id, :projects
      String :description
      String :file
    end
    alter_table(:dc_stains) do
      add_column :lineage_count, Integer
      add_column :hladr_count, Integer
      add_column :hladr_lineage_negative_count, Integer
      drop_column :t_count
    end
  end
end
