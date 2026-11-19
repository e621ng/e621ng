# frozen_string_literal: true

module Populate
  # Imports every tag, alias and implication from the exports. post_count keeps the production value.
  class Tags < Importer
    def call
      raise ArgumentError, "FIX_COUNTS needs imported posts; not available until doc 44 step 3" if options[:fix_counts]

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
      Cache.clear # cached implication descendants
      { tags: tags, aliases: aliases, implications: implications }
    end
  end
end
