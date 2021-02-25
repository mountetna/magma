class Magma
  class FilePredicate < Magma::ColumnPredicate
    def initialize question, model, alias_name, attribute, *query_args
      super
      @requested_md5_paths = Set.new
    end

    attr_reader :requested_md5_paths
    verb '::url' do
      child String

      extract do |table, identity|
        table.first[column_name] ? Magma.instance.storage.download_url(
          @model.project_name,
          table.first[column_name]["filename"]
        ) : nil
      end
    end

    def requested_md5(file_path)
      unless @requested_md5s
        # make request to metis
        host = Magma.instance.config(:storage).fetch(:host)

        client = Etna::Client.new("https://#{host}", @question.user.token)

        response = client.bucket_find(
          project_name: @model.project_name.to_s,
          bucket_name: 'magma',
          params: [{
            attribute: 'name',
            predicate: '=',
            value: @requested_md5_paths.to_a,
            type: 'file'
          }],
          signatory: Magma.instance
        )

        @requested_md5s = response[:files].map do |file|
          file.values_at(:file_name, :filehash)
        end.to_h
      end

      @requested_md5s[file_path]
    end

    class MD5Value
      def initialize(predicate, identifier, file)
        @predicate = predicate
        @identifier = identifier
        @file = file

        @predicate.requested_md5_paths << file
      end

      def to_json(options={})
        @predicate.requested_md5(@file).to_json
      end
    end

    verb '::md5' do
      child String

      extract do |table, identity|
        MD5Value.new(self, table.first[identity], table.first[column_name]["filename"])
      end
    end

    verb '::path' do
      child String

      extract do |table, identity|
        table.first[column_name] ? table.first[column_name]["filename"] : nil
      end
    end

    verb '::original_filename' do
      child String

      extract do |table, identity|
        table.first[column_name] ? table.first[column_name]["original_filename"] : nil
      end
    end

    verb '::all' do
      child String

      extract do |table, identity|
        table.first[column_name] ? table.first[column_name].symbolize_keys : nil
      end
    end

    def select
      [ Sequel[alias_name][@column_name].as(column_name) ]
    end
  end
end
