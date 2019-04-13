class Magma
  class ImageAttribute < FileAttribute
    def json_for record
      json = super

      json && json[:url] ?
        json.merge(
          thumb: Magma.instance.storage.download_url("thumb_#{record[@name]}")
        )
        : nil
    end
  end
end
