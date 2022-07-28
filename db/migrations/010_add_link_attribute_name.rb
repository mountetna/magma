Sequel.migration do
  up do
    alter_table(:attributes) do
      add_column :link_attribute_name, String
    end

    Magma.instance.db.execute("UPDATE attributes SET link_model_name=attribute_name WHERE attributes.link_model_name is NULL and attributes.type in ('parent', 'table', 'collection', 'child', 'link')")

    Magma.instance.db.execute("UPDATE attributes SET link_attribute_name=model_name WHERE attributes.link_model_name is not NULL and attribute_name!='reference_patient'")
    Magma.instance.db.execute("INSERT into attributes (project_name, model_name, attribute_name, link_model_name, type, column_name, link_attribute_name) VALUES ('ipi', 'patient', 'panel_patients', 'patient', 'collection', 'panel_patients', 'reference_patient')")
    Magma.instance.db.execute("UPDATE attributes SET link_attribute_name='panel_patients' WHERE attribute_name='reference_patient' and project_name='ipi' and model_name='patient'")
  end

  down do
    alter_table(:attributes) do
      drop_column :link_attribute_name
    end

    Magma.instance.db.execute("DELETE FROM attributes WHERE attribute_name='panel_patients' and project_name='ipi' and model_name='patient'")
  end
end
