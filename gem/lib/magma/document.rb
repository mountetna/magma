require 'fog'
require 'carrierwave/sequel'
class Magma
  class Document  < CarrierWave::Uploader::Base
    storage :fog
  end
end
