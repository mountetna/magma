class Magma
  class ImageAttribute < FileAttribute
    def json_payload(value)
      json = super

      json && json[:url] ?
        json.merge(
          thumb: Magma.instance.storage.download_url(@magma_model.project_name, "thumb_#{record[name]}")
        )
        : nil
    end
  end
end
