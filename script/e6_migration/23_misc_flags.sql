ALTER TABLE public.post_flags ALTER COLUMN is_resolved SET DEFAULT false;
ALTER TABLE public.post_flags ALTER COLUMN reason DROP NOT NULL;

alter table post_report_reasons rename column user_id to creator_id;
ALTER TABLE public.post_report_reasons ADD COLUMN creator_ip_addr inet;