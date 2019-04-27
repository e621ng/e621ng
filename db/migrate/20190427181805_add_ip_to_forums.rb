class AddIpToForums < ActiveRecord::Migration[5.2]
  def change
    ForumPost.without_timeout do
      add_column :forum_posts, :creator_ip_addr, :inet
      add_column :forum_topics, :creator_ip_addr, :inet
    end
  end
end
