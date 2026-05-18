-- CREATE CHEERS TABLE
CREATE TABLE IF NOT EXISTS public.cheers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    target_id UUID NOT NULL, -- Target user, asset, or session ID
    amount INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS POLICIES FOR CHEERS

ALTER TABLE public.cheers ENABLE ROW LEVEL SECURITY;

-- Anyone can read cheers
CREATE POLICY "Public cheers are viewable by everyone."
ON public.cheers FOR SELECT
USING ( true );

-- Users can insert their own cheers
CREATE POLICY "Users can insert their own cheers."
ON public.cheers FOR INSERT
WITH CHECK ( auth.uid() = user_id );

-- Users cannot update or delete cheers (append-only ledger)

-- RPC to securely accept cheers in bulk or singly if required by extreme scaling
CREATE OR REPLACE FUNCTION public.add_cheer(p_target_id UUID, p_amount INTEGER)
RETURNS UUID AS $$
DECLARE
    new_cheer_id UUID;
BEGIN
    INSERT INTO public.cheers (user_id, target_id, amount)
    VALUES (auth.uid(), p_target_id, p_amount)
    RETURNING id INTO new_cheer_id;
    
    RETURN new_cheer_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
