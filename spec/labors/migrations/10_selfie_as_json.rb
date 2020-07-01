Sequel.migration do
  up{run 'UPDATE labors.monsters SET selfie=\'{"filename":"\' || selfie || \'", "original_filename": ""}\';'\
         'alter table labors.monsters alter column selfie type json using selfie::json;'}
  down{run 'UPDATE labors.monsters SET selfie=selfie::json->\'filename\';'\
           'alter table labors.monsters alter column selfie type text;'\
           'UPDATE labors.monsters SET selfie=TRIM(\'"\' FROM selfie);'}
end
