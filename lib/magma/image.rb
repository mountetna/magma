require 'fog'
require 'carrierwave/sequel'

class Magma
  class Image  < CarrierWave::Uploader::Base
    include CarrierWave::MiniMagick
    storage :fog
    before :store, :run_loaders

    version :thumb do
      process resize_to_fit: [ 200, 400 ]
      process convert: 'png'
    end

    def filename
      file = model.send(mounted_as).file
      ext = file ? file.extension : 'dat'
      "#{model.class.name.snake_case}-#{mounted_as}-#{model.identifier}.#{ext}" if original_filename.present?
    end

    def run_loaders(file)
      model.run_loaders(mounted_as, file)
    end
  end
end
