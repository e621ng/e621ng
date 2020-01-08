ALTER TABLE public.api_keys DROP COLUMN IF EXISTS integer;
ALTER TABLE public.api_keys ALTER COLUMN key SET NOT NULL;
ALTER TABLE public.api_keys DROP COLUMN IF EXISTS string;
ALTER TABLE public.api_keys ALTER COLUMN user_id SET NOT NULL;