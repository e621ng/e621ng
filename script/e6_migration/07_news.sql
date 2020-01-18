-- news

alter table news rename to news_updates;
alter table news_updates rename column post to message;
alter table news_updates rename column user_id to creator_id;
alter table news_updates add column updater_id integer;
