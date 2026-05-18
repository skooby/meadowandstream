ALTER TABLE tags ADD COLUMN IF NOT EXISTS parent_id bigint REFERENCES tags(id) ON DELETE CASCADE;
ALTER TABLE tags ADD COLUMN IF NOT EXISTS type varchar(50) NOT NULL DEFAULT 'TAG';

-- To ensure folders can exist without localized strings conceptually if needed
ALTER TABLE tags ALTER COLUMN name_string_id DROP NOT NULL;

-- Optional: Rebuild RLS policy if we need specific folder permissions, but USING(true) already applies
