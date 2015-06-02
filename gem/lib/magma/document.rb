require 'fog'
require 'carrierwave/sequel'
class Magma
  class Document  < CarrierWave::Uploader::Base
    storage :fog
    before :store, :run_loaders

    def filename
      "#{model.class.name.snake_case}-#{model.identifier}.#{model.send(mounted_as).file.extension}"
    end

    def run_loaders(file)
      model.run_loaders(mounted_as, file)
    end
  end
end
