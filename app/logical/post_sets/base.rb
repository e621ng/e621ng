# frozen_string_literal: true

module PostSets
  class Base
    def tag_string
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
      children = ::Post.select(%i[id parent_id]).where(parent_id: ids).to_a.group_by(&:parent_id)
      posts.each { |p| p.inject_children(children[p.id] || []) }
    end

    def presenter
      raise NotImplementedError
    end

    def posts
      raise NotImplementedError
    end

    def related_tags
      @related_tags ||= begin
        tag_array = RelatedTagCalculator.calculate_from_posts_to_array(posts).map(&:first)
        tag_data = Tag.where(name: tag_array).select(:name, :post_count, :category).index_by(&:name)

        tag_array.map do |name|
          tag_data[name] || Tag.new(name: name).freeze
        end
      end
    end
  end
end
