-- Description: This adds the necessary search_keywords property column to the backend assets table 
-- matching our local Drift database schema version 53, enabling full lyric search mapping.

ALTER TABLE public.assets 
ADD COLUMN IF NOT EXISTS search_keywords text NULL;

-- Optional (Highly Recommended!): Provide generalized GIN indexed performance caching against the search_keywords 
-- text block so the Supabase DB evaluates text lookups instantly natively.
CREATE INDEX IF NOT EXISTS idx_assets_search_keywords_gin 
ON public.assets USING gin (to_tsvector('simple', coalesce(search_keywords, '')));
