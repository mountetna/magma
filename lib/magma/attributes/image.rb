class Magma
  class ImageAttribute < FileAttribute
    def json_for record
      json = super

      json && json[:url] ?
        json.merge(
          thumb: Magma.instance.storage.download_url(@model.project_name, "thumb_#{record[@name]}")
        )
        : nil
    end
  end
end
