-- pools

alter table pools rename column user_id to creator_id;
alter table pools drop column post_count;
alter table pools drop column is_locked;
alter table pools add column category character varying(30) not null default 'series',
add column is_deleted boolean not null default false;
-- Update to support locking in model
alter table pools add column post_ids integer[] not null default '{}'::integer[];
create index temp_pool_posts_ids on pools_posts(pool_id);
create unique index temp_pool_ids on pools(id);
update pools set post_ids = (select coalesce(array_agg(x.post_id), '{}'::integer[]) from (select _.post_id from pools_posts _ where _.pool_id = pools.id order by _.sequence) x);
drop table pools_posts;
drop index temp_pool_ids;

alter table pool_updates rename to pool_versions;
alter table pool_versions alter column post_ids drop default;
alter table pool_versions alter column post_ids type integer[] using (string_to_array(post_ids, ' ')::integer[]);
update pool_versions set post_ids = coalesce((select array_agg(val) from unnest(post_ids) with ordinality as t(val, idx) WHERE idx % 2 = 1), '{}'::integer[]);
alter table pool_versions alter column id type bigint;
alter table pool_versions rename column user_id to updater_id;
alter table pool_versions rename column ip_addr to updater_ip_addr;
alter table pool_versions add column name text,
add column name_changed boolean not null default false,
add column description text,
add column description_changed boolean not null default false,
add column is_active boolean not null default true,
add column is_locked boolean not null default true,
add column is_deleted boolean not null default true,
add column category varchar(30),
add column version integer not null default 1,
add column added_post_ids integer[] not null default '{}'::integer[],
add column removed_post_ids integer[] not null default '{}'::integer[];

ALTER TABLE public.pool_versions ALTER COLUMN is_deleted SET DEFAULT false;
ALTER TABLE public.pool_versions ALTER COLUMN post_ids SET DEFAULT '{}'::integer[];

create temp table pool_version_versions as select id, row_number() OVER (PARTITION BY pool_id ORDER BY id) as version FROM pool_versions;
update pool_versions pv set version = pvv.version from pool_version_versions pvv WHERE pv.id = pvv.id;
drop table pool_version_versions;

