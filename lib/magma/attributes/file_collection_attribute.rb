require_relative './file_copier'
require_relative './file_serializer'

class Magma
  class FileCollectionAttribute < Attribute
    def database_type
      :json
    end

    def serializer
      @serializer ||= FileSerializer.new(magma_model: @magma_model, attribute: self)
    end

    def revision_to_loader(record_name, files)
      loader_format = files.each_with_index.map do |revision, index|
        serializer.to_loader_format(record_name, revision, index)
      end
      [ name, loader_format ]
    end

    def revision_to_payload(record_name, files, loader)
      payload_format = files.each_with_index.map do |file_hash, index|
        serializer.to_payload_format(record_name, file_hash, loader.user, index)
      end
      [name, payload_format ]
    end

    def query_to_payload(data)
      data.map do |datum|
        serializer.to_query_payload_format(datum)
      end
    end

    def query_to_tsv(files)
      files.map do |file|
        serializer.to_query_tsv_format(file)
      end
    end

    def entry(files, loader)
      entry_format = files.map do |file|
        serializer.to_loader_entry_format(file)
      end.compact  # Remove the ::temp `nil` values for the loader

      [ column_name, entry_format.to_json ]
    end

    def load_hook(loader, record_name, files, copy_revisions)
      # Revising a FileCollectionAttribute makes some assumptions about the revisions.
      # We need to make sure that the links aren't lost on the Metis
      #   end of things, since that's the only pointer to the pre-revision data_block
      #   that we have for each Magma file.
      # For example,
      #     [file[1], file[0]] is a bad revision, because on Metis's end,
      #   after we update the new index-0 file (magma-file-0 -> original-magma-file-1-data-block),
      #   we lose the pointer to the original magma-file-0 data_block.
      #   It becomes impossible to do the magma-file-1 -> original-magma-file-0-data-block
      #   revision.
      # Thus, we must enforce these requirements:
      #   1) Any existing files must appear in ascending index order.
      #       [file[0], file[1], file[7], file[11]] is okay.
      #       [file[11], file[1], file[0], file[7]] is NOT okay.
      #   2) New files / Metis paths must appear at the end of the sequence.
      #       [file[1], file[8], {path: "metis://foo/bar/bim.txt"}] is okay.
      #       [{path: "metis://bad/revision/order.txt"}, file[1], file[8]] is NOT okay.
      #   3) Any ::temp files must be at the end of the array, so the filename indices stay sequential.
      #       [file[1], {path: "metis://foo/bar/bim.txt"}, "::temp"] is okay.
      #       [file[1], "::temp", {path: "metis://foo/bar/bim.txt"}] is not okay, because "bim.txt" will get assigned index 2 and
      #           they will appear to skip -- [file[0], file[2]] would be stored, instead of [file[0], file[1]].
      # In this hook we return an error message if any of the above
      #   requirements are not met, to stop the update.
      # Note: We'll also have to consider that "new files" may be ::temp or ::blank.

      return "Not all files have the required :path key." unless files.all? { |file| file&.dig(:path) }

      return "Existing files are not in ascending index order." unless existing_files_in_sequence?(record_name, files)

      return "New files must be at the end of the revision." unless new_files_at_end?(record_name, files)

      return "Temp files must be at the end of the revision." unless temp_files_at_end?(record_name, files)

      files.each_with_index do |file_revision, index|
        path = file_revision[:path]
        if path.start_with? 'metis://'
          copy_revisions[ path ] = "metis://#{project_name}/magma/#{serializer.filename(
            record_name: record_name,
            path: path,
            original_filename: file_revision[:original_filename],
            index: index)}"
        end
      end

      return nil
    end

    def self.type_bulk_load_hook(loader, project_name, attribute_copy_revisions)
      copier = FileCopier.new(loader, project_name, attribute_copy_revisions)
      copier.bulk_copy_files
    end

    private

    def is_existing_magma_file?(record_name, file_hash)
      # Tests if a file path in the list is an existing file
      #   in the Magma bucket on Metis instead of a new file.
      path = file_hash[:path]
      indexless_filename = serializer.filename(record_name: record_name, path: path)
      expected_basename = File.basename(indexless_filename, File.extname(indexless_filename))
      path.include?('/magma/') && File.basename(path).start_with?(expected_basename)
    end

    def existing_files_in_sequence?(record_name, files)
      # Tests if the existing files in a set of revisions
      #   are in ascending sequence order.
      existing_files = files.select do |file_revision|
        is_existing_magma_file?(record_name, file_revision)
      end

      index_order = existing_files.map do |file_revision|
        File.basename(file_revision[:path]).split('-').last.to_i
      end

      index_order == index_order.sort
    end

    def new_files_at_end?(record_name, files)
      # Tests if any new Metis paths in a set of revisions
      #   are at the end of the set.
      seen_new_file = false
      files.each do |file_revision|
        return false if seen_new_file && is_existing_magma_file?(record_name, file_revision)
        seen_new_file = true if !is_existing_magma_file?(record_name, file_revision)
      end

      true
    end

    def temp_files_at_end?(record_name, files)
      # Tests if all the "::temp" revisions
      #   are at the end -- this keeps the indexing
      #   intuitive so no indices are skipped
      #   in the new filenames.
      seen_temp_file = false
      files.each do |file_revision|
        path = file_revision[:path]
        return false if seen_temp_file && serializer.temp != path
        seen_temp_file = true if serializer.temp == path
      end

      true
    end
  end
end
