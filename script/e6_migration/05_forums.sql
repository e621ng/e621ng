-- Forums

drop trigger trg_forum_post_search_update on forum_posts;

CREATE TABLE forum_topics (
    id serial NOT NULL,
    creator_id integer NOT NULL,
    creator_ip_addr inet NOT NULL,
    updater_id integer NOT NULL,
    title character varying(255) NOT NULL,
    response_count integer DEFAULT 0 NOT NULL,
    is_sticky boolean DEFAULT false NOT NULL,
    is_locked boolean DEFAULT false NOT NULL,
    is_hidden boolean DEFAULT false NOT NULL,
    text_index tsvector NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    category_id integer NOT NULL DEFAULT 0,
    min_level integer NOT NULL DEFAULT 0,
    original_post_id integer
);

ALTER TABLE ONLY forum_topics
    ADD CONSTRAINT forum_topics_pkey PRIMARY KEY (id);
CREATE TRIGGER trigger_forum_topics_on_update
    BEFORE INSERT OR UPDATE ON forum_topics
    FOR EACH ROW
    EXECUTE PROCEDURE tsvector_update_trigger('text_index', 'pg_catalog.english', 'title');


insert into forum_topics (creator_id, updater_id, title, response_count, is_sticky, is_locked, text_index, created_at, updated_at, is_hidden, category_id, creator_ip_addr, original_post_id) select forum_posts.creator_id, forum_posts.creator_id, forum_posts.title, forum_posts.response_count, forum_posts.is_sticky, forum_posts.is_locked, forum_posts.text_search_index, forum_posts.created_at, forum_posts.updated_at, forum_posts.status = 'hidden', forum_posts.category_id, ip_addr, forum_posts.id
from forum_posts where parent_id is null;

create index temp_ft_original_post_id on forum_topics(original_post_id);
create index temp_fp_parent_id on forum_posts(parent_id);

alter table forum_posts add column topic_id integer;
update forum_posts set topic_id = (select forum_topics.id from forum_topics where forum_topics.original_post_id = forum_posts.parent_id) where forum_posts.parent_id is not null;
update forum_posts set topic_id = (select forum_topics.id from forum_topics where forum_topics.original_post_id = forum_posts.id) where forum_posts.parent_id is null;

drop index temp_ft_original_post_id;
drop index temp_fp_parent_id;

alter table forum_topics drop column original_post_id;

alter table forum_posts rename column last_updated_by to updater_id;
alter table forum_posts rename column text_search_index to text_index;
alter table forum_posts rename column ip_addr to creator_ip_addr;
ALTER TABLE public.forum_posts DROP COLUMN IF EXISTS category_id;
alter table forum_posts drop column parent_id;
alter table forum_posts drop column is_sticky;
alter table forum_posts drop column is_locked;
alter table forum_posts drop column title;
alter table forum_posts drop column response_count;
alter table forum_posts add column is_hidden boolean not null default false;
update forum_posts set is_hidden = true where status = 'hidden';
alter table forum_posts drop column status;

alter table forum_categories rename column "order" to cat_order;
