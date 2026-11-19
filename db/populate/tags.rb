# frozen_string_literal: true

module Populate
  # Imports every tag, alias and implication from the exports. post_count keeps the production value.
  class Tags < Importer
    # Sets every tag's post_count to its number of undeleted local posts, as Tag#fix_post_count
    # would one tag at a time. Tags without local posts drop to zero.
    def self.fix_counts!
      puts "* Recounting tags from local posts"
      changed = Exports.with_timeout_off do
        ActiveRecord::Base.connection.execute(<<~SQL.squish).cmd_tuples
          WITH counts AS (
            SELECT name, COUNT(*) AS total
            FROM (SELECT unnest(string_to_array(tag_string, ' ')) AS name FROM posts WHERE NOT is_deleted) x
            GROUP BY name
          )
          UPDATE tags SET post_count = COALESCE(counts.total, 0)
          FROM tags t LEFT JOIN counts ON counts.name = t.name
          WHERE tags.id = t.id AND tags.post_count IS DISTINCT FROM COALESCE(counts.total, 0)
        SQL
      end
      puts "  #{changed} counts changed"
      changed
    end

    def call
      ensure_loaded!("tags", "tag_aliases", "tag_implications")
      log "* Importing tags"

      tags = insert(<<~SQL.squish)
        INSERT INTO tags (id, name, category, post_count, created_at, updated_at, is_locked)
        SELECT id, name, COALESCE(category, 0), COALESCE(post_count, 0), created_at, updated_at, COALESCE(is_locked, false)
        FROM #{SEED}.tags
        ON CONFLICT DO NOTHING
      SQL
      log "  tags: #{tags} inserted"

      stub_users_for(<<~SQL.squish)
        SELECT creator_id FROM #{SEED}.tag_aliases UNION SELECT approver_id FROM #{SEED}.tag_aliases
        UNION SELECT creator_id FROM #{SEED}.tag_implications UNION SELECT approver_id FROM #{SEED}.tag_implications
      SQL

      # Forum topics and posts are not exported, so those references are dropped.
      aliases = insert(<<~SQL.squish)
        INSERT INTO tag_aliases (id, antecedent_name, consequent_name, creator_id, creator_ip_addr, forum_topic_id, status,
                                 created_at, updated_at, post_count, approver_id, forum_post_id, reason)
        SELECT id, antecedent_name, consequent_name, creator_id, '#{LOCAL_IP}', NULL, status,
               created_at, updated_at, COALESCE(post_count, 0), approver_id, NULL, COALESCE(reason, '')
        FROM #{SEED}.tag_aliases
        ON CONFLICT DO NOTHING
      SQL
      log "  aliases: #{aliases} inserted"

      implications = insert(<<~SQL.squish)
        INSERT INTO tag_implications (id, antecedent_name, consequent_name, creator_id, creator_ip_addr, forum_topic_id, status,
                                      created_at, updated_at, approver_id, forum_post_id, descendant_names, reason)
        SELECT id, antecedent_name, consequent_name, creator_id, '#{LOCAL_IP}', NULL, status,
               created_at, updated_at, approver_id, NULL, COALESCE(descendant_names, '{}')::text[], COALESCE(reason, '')
        FROM #{SEED}.tag_implications
        ON CONFLICT DO NOTHING
      SQL
      log "  implications: #{implications} inserted"

      bump_sequences!("tags", "tag_aliases", "tag_implications")
      self.class.fix_counts! if options[:fix_counts]
      Cache.clear # cached implication descendants and tag lookups
      { tags: tags, aliases: aliases, implications: implications }
    end
  end
end
