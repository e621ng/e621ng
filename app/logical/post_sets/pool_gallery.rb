module PostSets
  class PoolGallery < PostSets::Base
    attr_reader :pools

    def initialize(pools)
      @pools = pools
    end

    def presenter
      @presenter ||= ::PostSetPresenters::PoolGallery.new(self)
    end
  end
end
