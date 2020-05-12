require 'pry'

describe 'Magma::Storage' do
    include Rack::Test::Methods

    def app
      OUTER_APP
    end

    it 'returns a download URL.' do
        # The test config is usually Metis storage, but
        #   let's make this conditional just in case not.
        if Magma.instance.config(:storage).fetch(:provider).downcase == 'metis'
            download_url = Magma.instance.storage.download_url('foo', 'root/path/to/file').to_s
            expect(download_url.include? 'foo/download/magma/root/path/to/file').to be true

            # While we won't validate the HMAC results, let's make sure
            #   the right params are included
            expect(download_url.include? 'X-Etna-Authorization').to be true
            expect(download_url.include? 'X-Etna-Expiration').to be true
            expect(download_url.include? 'X-Etna-Nonce').to be true
            expect(download_url.include? 'X-Etna-Id').to be true
            expect(download_url.include? 'X-Etna-Headers').to be true

            # Just to make sure we're sane
            expect(download_url.include? 'upload/magma').to be false
            expect(download_url.include? 'file/copy/magma').to be false
        end
    end

    it 'returns an upload URL.' do
        # The test config is usually Metis storage, but
        #   let's make this conditional just in case not.
        if Magma.instance.config(:storage).fetch(:provider).downcase == 'metis'
            upload_url = Magma.instance.storage.upload_url('foo', 'root/path/to/file').to_s
            expect(upload_url.include? 'foo/upload/magma/root/path/to/file').to be true

            # While we won't validate the HMAC results, let's make sure
            #   the right params are included
            expect(upload_url.include? 'X-Etna-Authorization').to be true
            expect(upload_url.include? 'X-Etna-Expiration').to be true
            expect(upload_url.include? 'X-Etna-Nonce').to be true
            expect(upload_url.include? 'X-Etna-Id').to be true
            expect(upload_url.include? 'X-Etna-Headers').to be true

            # Just to make sure we're sane
            expect(upload_url.include? 'download/magma').to be false
            expect(upload_url.include? 'file/copy/magma').to be false
        end
    end
  end
