ALTER TABLE public.edit_histories ALTER COLUMN created_at SET NOT NULL;
ALTER TABLE public.edit_histories ALTER COLUMN id TYPE bigint;
ALTER TABLE public.edit_histories ADD COLUMN subject text;
ALTER TABLE public.edit_histories ALTER COLUMN updated_at SET NOT NULL;