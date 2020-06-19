Sequel.migration do
  up{run 'UPDATE labors.monsters SET stats=\'{"filename":"\' || stats || \'", "original_filename": ""}\';'\
         'alter table labors.monsters alter column stats type json using stats::json;'}
  down{run 'UPDATE labors.monsters SET stats=stats::json->\'filename\';'\
           'alter table labors.monsters alter column stats type text;'\
           'UPDATE labors.monsters SET stats=TRIM(\'"\' FROM stats);'}
end
