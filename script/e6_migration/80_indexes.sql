CREATE EXTENSION pg_trgm;


CREATE UNIQUE INDEX index_api_keys_on_key ON api_keys USING btree (key);
CREATE UNIQUE INDEX index_api_keys_on_user_id ON api_keys USING btree (user_id);
CREATE UNIQUE INDEX index_artist_commentaries_on_post_id ON artist_commentaries USING btree (post_id);
CREATE INDEX index_artist_commentary_versions_on_post_id ON artist_commentary_versions USING btree (post_id);
CREATE INDEX index_artist_commentary_versions_on_updater_id_and_post_id ON artist_commentary_versions USING btree (updater_id, post_id);
CREATE INDEX index_artist_commentary_versions_on_updater_ip_addr ON artist_commentary_versions USING btree (updater_ip_addr);
CREATE INDEX index_artist_urls_on_artist_id ON artist_urls USING btree (artist_id);
CREATE INDEX index_artist_urls_on_normalized_url_pattern ON artist_urls USING btree (normalized_url text_pattern_ops);
CREATE INDEX index_artist_versions_on_artist_id ON artist_versions USING btree (artist_id);
CREATE INDEX index_artist_versions_on_created_at ON artist_versions USING btree (created_at);
CREATE INDEX index_artist_versions_on_name ON artist_versions USING btree (name);
CREATE INDEX index_artist_versions_on_updater_id ON artist_versions USING btree (updater_id);
CREATE INDEX index_artist_versions_on_updater_ip_addr ON artist_versions USING btree (updater_ip_addr);
CREATE INDEX index_artists_on_group_name ON artists USING btree (group_name);
CREATE UNIQUE INDEX index_artists_on_name ON artists USING btree (name);
CREATE INDEX index_artists_on_other_names ON artists USING gin (other_names);
CREATE INDEX index_bans_on_banner_id ON bans USING btree (banner_id);
CREATE INDEX index_bans_on_expires_at ON bans USING btree (expires_at);
CREATE INDEX index_bans_on_user_id ON bans USING btree (user_id);
CREATE INDEX index_blips_on_body_index ON blips USING gin (body_index);
CREATE INDEX index_bulk_update_requests_on_forum_post_id ON bulk_update_requests USING btree (forum_post_id);


CREATE INDEX index_comment_votes_on_comment_id ON comment_votes USING btree (comment_id);
CREATE INDEX index_comment_votes_on_created_at ON comment_votes USING btree (created_at);
CREATE INDEX index_comment_votes_on_user_id ON comment_votes USING btree (user_id);
CREATE UNIQUE INDEX index_comment_votes_on_comment_id_and_user_id ON comment_votes USING btree (comment_id, user_id);
CREATE INDEX index_comments_on_body_index ON comments USING gin (body_index);
CREATE INDEX index_comments_on_creator_id_and_post_id ON comments USING btree (creator_id, post_id);
CREATE INDEX index_comments_on_creator_ip_addr ON comments USING btree (creator_ip_addr);
CREATE INDEX index_comments_on_post_id ON comments USING btree (post_id);


CREATE UNIQUE INDEX index_dmail_filters_on_user_id ON dmail_filters USING btree (user_id);
CREATE INDEX index_dmails_on_creator_ip_addr ON dmails USING btree (creator_ip_addr);
CREATE INDEX index_dmails_on_is_deleted ON dmails USING btree (is_deleted);
CREATE INDEX index_dmails_on_is_read ON dmails USING btree (is_read);
CREATE INDEX index_dmails_on_message_index ON dmails USING gin (message_index);
CREATE INDEX index_dmails_on_owner_id ON dmails USING btree (owner_id);
CREATE INDEX index_edit_histories_on_user_id ON edit_histories USING btree (user_id);
CREATE INDEX index_edit_histories_on_versionable_id_and_versionable_type ON edit_histories USING btree (versionable_id, versionable_type);
CREATE INDEX index_forum_post_votes_on_forum_post_id ON forum_post_votes USING btree (forum_post_id);

-- Deduplicate
DELETE FROM favorites a USING favorites b
    WHERE a.id < b.id
    AND a.user_id = b.user_id AND a.post_id = b.post_id;
CREATE UNIQUE INDEX index_favorites_on_user_id_and_post_id ON favorites USING btree (user_id, post_id);
CREATE INDEX index_favorites_on_post_id ON favorites USING btree (post_id);


CREATE UNIQUE INDEX index_forum_post_votes_on_forum_post_id_and_creator_id ON forum_post_votes USING btree (forum_post_id, creator_id);
CREATE INDEX index_forum_posts_on_creator_id ON forum_posts USING btree (creator_id);
CREATE INDEX index_forum_posts_on_text_index ON forum_posts USING gin (text_index);
CREATE INDEX index_forum_posts_on_topic_id ON forum_posts USING btree (topic_id);
CREATE INDEX index_forum_subscriptions_on_forum_topic_id ON forum_subscriptions USING btree (forum_topic_id);
CREATE INDEX index_forum_subscriptions_on_user_id ON forum_subscriptions USING btree (user_id);
CREATE INDEX index_forum_topic_visits_on_forum_topic_id ON forum_topic_visits USING btree (forum_topic_id);
CREATE INDEX index_forum_topic_visits_on_last_read_at ON forum_topic_visits USING btree (last_read_at);
CREATE INDEX index_forum_topic_visits_on_user_id ON forum_topic_visits USING btree (user_id);
CREATE INDEX index_forum_topics_on_creator_id ON forum_topics USING btree (creator_id);
CREATE INDEX index_forum_topics_on_is_sticky_and_updated_at ON forum_topics USING btree (is_sticky, updated_at);
CREATE INDEX index_forum_topics_on_text_index ON forum_topics USING gin (text_index);
CREATE INDEX index_forum_topics_on_updated_at ON forum_topics USING btree (updated_at);


CREATE UNIQUE INDEX index_ip_bans_on_ip_addr ON ip_bans USING btree (ip_addr);


CREATE INDEX index_janitor_trials_on_user_id ON janitor_trials USING btree (user_id);
CREATE INDEX index_news_updates_on_created_at ON news_updates USING btree (created_at);
CREATE INDEX index_note_versions_on_created_at ON note_versions USING btree (created_at);
CREATE INDEX index_note_versions_on_note_id ON note_versions USING btree (note_id);
CREATE INDEX index_note_versions_on_post_id ON note_versions USING btree (post_id);
CREATE INDEX index_note_versions_on_updater_id_and_post_id ON note_versions USING btree (updater_id, post_id);
CREATE INDEX index_note_versions_on_updater_ip_addr ON note_versions USING btree (updater_ip_addr);
CREATE INDEX index_notes_on_body_index ON notes USING gin (body_index);
CREATE INDEX index_notes_on_creator_id_and_post_id ON notes USING btree (creator_id, post_id);
CREATE INDEX index_notes_on_post_id ON notes USING btree (post_id);
CREATE UNIQUE INDEX index_pixiv_ugoira_frame_data_on_post_id ON pixiv_ugoira_frame_data USING btree (post_id);
CREATE INDEX index_pool_versions_on_pool_id ON pool_versions USING btree (pool_id);
CREATE INDEX index_pool_versions_on_updater_id ON pool_versions USING btree (updater_id);
CREATE INDEX index_pool_versions_on_updater_ip_addr ON pool_versions USING btree (updater_ip_addr);
ALTER TABLE public.pool_versions ADD CONSTRAINT pool_versions_pkey PRIMARY KEY (id); -- (1);
CREATE INDEX index_pools_on_creator_id ON pools USING btree (creator_id);
CREATE INDEX index_pools_on_lower_name ON pools USING btree (lower(name::text));
CREATE INDEX index_pools_on_name ON pools USING btree (name);
CREATE INDEX index_pools_on_updated_at ON pools USING btree (updated_at);
CREATE INDEX index_pools_on_post_ids ON pools USING gin (post_ids);


CREATE INDEX index_post_appeals_on_created_at ON post_appeals USING btree (created_at);
CREATE INDEX index_post_appeals_on_creator_id ON post_appeals USING btree (creator_id);
CREATE INDEX index_post_appeals_on_creator_ip_addr ON post_appeals USING btree (creator_ip_addr);
CREATE INDEX index_post_appeals_on_post_id ON post_appeals USING btree (post_id);
CREATE INDEX index_post_appeals_on_reason_tsvector ON post_appeals USING gin (to_tsvector('english'::regconfig, reason));
CREATE INDEX index_post_approvals_on_post_id ON post_approvals USING btree (post_id);
CREATE INDEX index_post_approvals_on_user_id ON post_approvals USING btree (user_id);
CREATE INDEX index_post_disapprovals_on_post_id ON post_disapprovals USING btree (post_id);
CREATE INDEX index_post_disapprovals_on_user_id ON post_disapprovals USING btree (user_id);
CREATE INDEX index_post_flags_on_creator_id ON post_flags USING btree (creator_id);
CREATE INDEX index_post_flags_on_creator_ip_addr ON post_flags USING btree (creator_ip_addr);
CREATE INDEX index_post_flags_on_post_id ON post_flags USING btree (post_id);
CREATE INDEX index_post_flags_on_reason_tsvector ON post_flags USING gin (to_tsvector('english'::regconfig, reason));
CREATE INDEX index_post_replacements_on_creator_id ON post_replacements USING btree (creator_id);
CREATE INDEX index_post_replacements_on_post_id ON post_replacements USING btree (post_id);

CREATE INDEX index_post_sets_on_post_ids ON post_sets USING gin (post_ids);


CREATE INDEX index_post_versions_on_post_id ON post_versions USING btree (post_id);
CREATE INDEX index_post_versions_on_updated_at ON post_versions USING btree (updated_at);
CREATE INDEX index_post_versions_on_updater_id ON post_versions USING btree (updater_id);
CREATE INDEX index_post_versions_on_updater_ip_addr ON post_versions USING btree (updater_ip_addr);
ALTER TABLE public.post_versions ADD CONSTRAINT post_versions_pkey PRIMARY KEY (id); -- (1);


-- Deduplicate
create index tmp_post_votes on post_votes(user_id, post_id);
DELETE FROM post_votes a USING post_votes b
    WHERE a.id < b.id
    AND a.user_id = b.user_id AND a.post_id = b.post_id;
drop index tmp_post_votes;
CREATE UNIQUE INDEX index_post_votes_on_user_id_and_post_id ON post_votes USING btree (user_id, post_id);
CREATE INDEX index_post_votes_on_post_id ON post_votes USING btree (post_id);


CREATE INDEX index_posts_on_file_size ON posts USING btree (file_size);
CREATE INDEX index_posts_on_image_height ON posts USING btree (image_height);
CREATE INDEX index_posts_on_image_width ON posts USING btree (image_width);
CREATE INDEX index_posts_on_is_flagged ON posts USING btree (is_flagged) WHERE is_flagged = true;
CREATE INDEX index_posts_on_is_pending ON posts USING btree (is_pending) WHERE is_pending = true;
CREATE INDEX index_posts_on_last_comment_bumped_at ON posts USING btree (last_comment_bumped_at DESC NULLS LAST);
CREATE INDEX index_posts_on_last_noted_at ON posts USING btree (last_noted_at DESC NULLS LAST);
CREATE INDEX index_posts_on_mpixels ON posts USING btree (((image_width * image_height)::numeric / 1000000.0));
CREATE INDEX index_posts_on_source ON posts USING btree (lower(source::text));
CREATE INDEX index_posts_on_tags_index ON posts USING gin (tag_index);
CREATE UNIQUE INDEX index_posts_on_change_seq ON posts USING btree (change_seq);
CREATE INDEX index_posts_on_created_at ON posts USING btree (created_at);
CREATE UNIQUE INDEX index_posts_on_md5 ON posts USING btree (md5);
CREATE INDEX index_posts_on_parent_id ON posts USING btree (parent_id);
CREATE INDEX index_posts_on_uploader_id ON posts USING btree (uploader_id);
CREATE INDEX index_posts_on_uploader_ip_addr ON posts USING btree (uploader_ip_addr);


CREATE INDEX index_saved_searches_on_labels ON saved_searches USING gin (labels);
CREATE INDEX index_saved_searches_on_query ON saved_searches USING btree (query);
CREATE INDEX index_saved_searches_on_user_id ON saved_searches USING btree (user_id);
CREATE INDEX index_tag_aliases_on_antecedent_name ON tag_aliases USING btree (antecedent_name);
CREATE INDEX index_tag_aliases_on_antecedent_name_pattern ON tag_aliases USING btree (antecedent_name text_pattern_ops);
CREATE INDEX index_tag_aliases_on_consequent_name ON tag_aliases USING btree (consequent_name);
CREATE INDEX index_tag_aliases_on_forum_post_id ON tag_aliases USING btree (forum_post_id);
CREATE INDEX index_tag_aliases_on_post_count ON tag_aliases USING btree (post_count);
CREATE INDEX index_tag_implications_on_antecedent_name ON tag_implications USING btree (antecedent_name);
CREATE INDEX index_tag_implications_on_consequent_name ON tag_implications USING btree (consequent_name);
CREATE INDEX index_tag_implications_on_forum_post_id ON tag_implications USING btree (forum_post_id);
CREATE INDEX index_tag_type_versions_on_creator_id ON tag_type_versions USING btree (creator_id);
CREATE INDEX index_tag_type_versions_on_tag_id ON tag_type_versions USING btree (tag_id);

CREATE INDEX index_tag_rel_undos_on_tag_rel_type_and_tag_rel_id ON tag_rel_undos USING btree (tag_rel_type, tag_rel_id);
ALTER TABLE tag_rel_undos ADD CONSTRAINT tag_rel_undos_pkey PRIMARY KEY (id);


CREATE UNIQUE INDEX index_tags_on_name ON tags USING btree (name);
CREATE INDEX index_tags_on_name_pattern ON tags USING btree (name text_pattern_ops);
CREATE INDEX index_uploads_on_referer_url ON uploads USING btree (referer_url);
CREATE INDEX index_uploads_on_source ON uploads USING btree (source);
CREATE INDEX index_uploads_on_uploader_id ON uploads USING btree (uploader_id);
CREATE INDEX index_uploads_on_uploader_ip_addr ON uploads USING btree (uploader_ip_addr);
CREATE INDEX index_user_feedback_on_created_at ON user_feedback USING btree (created_at);
CREATE INDEX index_user_feedback_on_creator_id ON user_feedback USING btree (creator_id);
CREATE INDEX index_user_feedback_on_creator_ip_addr ON user_feedback USING btree (creator_ip_addr);
CREATE INDEX index_user_feedback_on_user_id ON user_feedback USING btree (user_id);
CREATE INDEX index_user_name_change_requests_on_original_name ON user_name_change_requests USING btree (original_name);
CREATE INDEX index_user_name_change_requests_on_user_id ON user_name_change_requests USING btree (user_id);


ALTER TABLE public.user_password_reset_nonces ADD CONSTRAINT user_password_reset_nonces_pkey PRIMARY KEY (id); -- (1);


CREATE UNIQUE INDEX index_user_statuses_on_user_id ON user_statuses USING btree (user_id);
ALTER TABLE public.user_statuses ADD CONSTRAINT user_statuses_pkey PRIMARY KEY (id); -- (1);
CREATE INDEX index_users_on_email ON users USING btree (email); -- TODO: UNIQUE
CREATE INDEX index_users_on_last_ip_addr ON users USING btree (last_ip_addr) WHERE last_ip_addr IS NOT NULL;
CREATE UNIQUE INDEX index_users_on_name ON users USING btree (lower(name::text));

CREATE INDEX index_wiki_page_versions_on_created_at ON wiki_page_versions USING btree (created_at);
CREATE INDEX index_wiki_page_versions_on_updater_ip_addr ON wiki_page_versions USING btree (updater_ip_addr);
CREATE INDEX index_wiki_page_versions_on_wiki_page_id ON wiki_page_versions USING btree (wiki_page_id);
CREATE INDEX index_wiki_pages_on_body_index_index ON wiki_pages USING gin (body_index);
CREATE INDEX index_wiki_pages_on_other_names ON wiki_pages USING gin (other_names);
CREATE UNIQUE INDEX index_wiki_pages_on_title ON wiki_pages USING btree (title);
CREATE INDEX index_wiki_pages_on_title_pattern ON wiki_pages USING btree (title text_pattern_ops);
CREATE INDEX index_wiki_pages_on_updated_at ON wiki_pages USING btree (updated_at);
