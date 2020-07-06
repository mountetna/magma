class Magma
  class ImageAttribute < FileAttribute
    def json_payload(value)
      json = super

      # This will be different once we get a new thumbnail URL on Metis
      json && json[:url] ?
        json.merge(
          thumb: Magma.instance.storage.download_url(@magma_model.project_name, "thumb_#{record[name]}")
        )
        : nil
    end
  end
end
