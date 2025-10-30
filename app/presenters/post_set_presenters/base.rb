# frozen_string_literal: true

module PostSetPresenters
  class Base
    def posts
      raise NotImplementedError
    end
  end
end
