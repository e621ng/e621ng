module PostSets
  class Base
    def tag_string
      ""
    end

    def public_tag_string
      ""
    end

    def ad_tag_string
      ""
    end

    def fill_tag_types(posts)
      tag_array = []
      posts.each do |p|
        tag_array = (p.tag_array + tag_array).uniq
      end
      types = Tag.categories_for(tag_array)
      posts.each do |p|
        p.inject_tag_categories(types)
      end
    end

    def fill_children(posts)
      posts = posts.filter(&:has_children?)
      ids = posts.map(&:id)
      children = ::Post.select([:id, :parent_id]).where(parent_id: ids).to_a.group_by {|p| p.parent_id}
      posts.each do |p|
        p.inject_children(children[p.id] || [])
      end
    end

    def presenter
      raise NotImplementedError
    end
  end
end
