begin;

alter table tags rename column tag_type to category;
alter table tags rename column type_locked to is_locked;
alter table tags rename column cached_related to related_tags;
alter table tags rename column cached_related_expires_on to related_tags_updated_at;
update tags set is_locked = false where is_locked is null;
alter table tags alter column is_locked set not null;
alter table tags add column created_at timestamp not null default now(),
add column updated_at timestamp not null default now();
alter table tags alter column related_tags drop not null,
alter column related_tags_updated_at drop not null;
alter table tags add primary key (id);

alter table tag_aliases rename column name to antecedent_name;
alter table tag_aliases add column updated_at timestamp,
add column forum_topic_id integer,
add column creator_ip_addr inet not null default '127.0.0.1',
add column consequent_name varchar,
add column status varchar not null default 'pending',
add column post_count int not null default 0,
add column approver_id integer;
update tag_aliases set status = 'active' where is_pending = false;
alter table tag_aliases drop column is_pending;
update tag_aliases set consequent_name = (select _.name from tags _ where _.id = tag_aliases.alias_id);
alter table tag_aliases drop column alias_id;
update tag_aliases set creator_id = 1 where creator_id is null;
alter table tag_aliases alter column creator_id set not null,
alter column consequent_name set not null;

alter table forum_posts add primary key (id);
update tag_aliases set forum_topic_id = (select _.topic_id from forum_posts _ where _.id = tag_aliases.forum_post_id);

alter table tag_implications add column antecedent_name varchar,
add column consequent_name varchar,
add column status varchar not null default 'pending',
add column creator_ip_addr inet not null default '127.0.0.1',
add column forum_topic_id int,
add column updated_at timestamp,
add column descendant_names text[] default '{}'::text[],
add column approver_id integer;
update tag_implications set status = 'active' where is_pending = false;
alter table tag_implications drop column is_pending;
update tag_implications set antecedent_name = (select _.name from tags _ where _.id = tag_implications.predicate_id), consequent_name = (select _.name from tags _ where _.id = tag_implications.consequent_id);
alter table tag_implications alter column antecedent_name set not null, alter column consequent_name set not null;
update tag_implications set forum_topic_id = (select _.topic_id from forum_posts _ where _.id = tag_implications.forum_post_id);
update tag_implications set creator_id = 1 where creator_id is null;
alter table tag_implications alter column creator_id set not null;
alter table tag_implications drop column consequent_id, drop column predicate_id;

alter table forum_posts drop constraint forum_posts_pkey;
alter table tags drop constraint tags_pkey;

alter table tag_type_histories rename to tag_type_versions;
alter table tag_type_versions rename column user_id to creator_id;

commit;
