Sequel.migration do
  up do
    alter_table(:experiments) do
      add_column :short_name, String
    end

    tumor_types = {
      :Colorectal => :CRC,
      :Melanoma => :MEL,
      :"Head and Neck" => :HNSC,
      :Gynecologic => :GYN,
      :Kidney => :KID,
      :Breast => :BRC,
      :Lung => :LUNG,
      :Liver => :LIV,
      :Bladder => :BLAD,
      :Prostate => :PROS,
      :Pancreas => :PDAC,
      :Neuroendocrine => :PNET,
      :Gastric => :GSTR
    }

    self[:experiments].where(name: tumor_types.keys.map(&:to_s)).all do |exp|
      self[:experiments].filter(id: exp[:id]).
        update(short_name: tumor_types[exp[:name].to_sym].to_s)
    end
  end
  down do
    alter_table(:experiments) do
      drop_column :short_name
    end
  end
end
