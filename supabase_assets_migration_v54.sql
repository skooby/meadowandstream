-- Description: This adds the necessary alternate_version_ids property columns to the backend assets table to map links to other versions.

ALTER TABLE public.assets 
ADD COLUMN IF NOT EXISTS alternate_version_ids TEXT DEFAULT NULL;
