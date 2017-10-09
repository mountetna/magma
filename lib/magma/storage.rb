class Magma
  class Storage
    def initialize
      @config = Magma.instance.config(:storage)
      if use_fog?
        @fog = Fog::Storage.new(@config[:credentials])
      end
    end

    def get_url path
      if use_fog?
        @fog.get_object_url(
          @config[:directory],
          "uploads/#{path}",
          Time.now + @config[:expiration]*60,
          path_style: true
        )
      end
    end

    private

    def use_fog?
      @config[:provider] == 'fog/aws'
    end
  end
end
