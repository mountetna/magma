require 'fog'
require 'carrierwave/sequel'
require 'carrierwave/processing/mini_magick'

class Magma
  class Image  < CarrierWave::Uploader::Base
    storage :fog
    before :store, :run_loaders


    version :thumb do
      process resize_to_fit: [ 200, 400 ]
      process convert: 'png'
    end

    def filename
      "#{model.class.name.snake_case}-#{model.identifier}.#{model.send(mounted_as).file.extension}"
    end

    def run_loaders(file)
      model.run_loaders(mounted_as, file)
    end
  end
end
