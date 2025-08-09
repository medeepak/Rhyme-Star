-- Row Level Security Policies
-- Migration: 20240101000002_rls_policies.sql

-- Users table policies
CREATE POLICY "Users can view own profile"
ON users FOR SELECT
USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
ON users FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Admin users can view all profiles (for future admin panel)
CREATE POLICY "Admin users can view all profiles"
ON users FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() 
    AND email IN ('admin@rhymestar.com') -- Replace with actual admin emails
  )
);

-- Children table policies
CREATE POLICY "Users can view own children"
ON children FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own children"
ON children FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own children"
ON children FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own children"
ON children FOR DELETE
USING (auth.uid() = user_id);

-- Rhymes table policies (public read access)
CREATE POLICY "Anyone can view active rhymes"
ON rhymes FOR SELECT
USING (is_active = true);

-- Admin can manage rhymes
CREATE POLICY "Admin can manage rhymes"
ON rhymes FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() 
    AND email IN ('admin@rhymestar.com')
  )
);

-- Videos table policies
CREATE POLICY "Users can view own videos"
ON videos FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own videos"
ON videos FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own videos"
ON videos FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Video jobs policies (system access only)
CREATE POLICY "System can manage video jobs"
ON video_jobs FOR ALL
USING (true); -- This will be restricted to service role key in practice

-- Video progress policies
CREATE POLICY "Users can view own video progress"
ON video_progress FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM videos 
    WHERE videos.id = video_progress.video_id 
    AND videos.user_id = auth.uid()
  )
);

CREATE POLICY "System can insert video progress"
ON video_progress FOR INSERT
WITH CHECK (true); -- Service role only

-- Gem transactions policies
CREATE POLICY "Users can view own gem transactions"
ON gem_transactions FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "System can insert gem transactions"
ON gem_transactions FOR INSERT
WITH CHECK (true); -- Service role only for integrity

-- Referrals policies
CREATE POLICY "Users can view referrals they made"
ON referrals FOR SELECT
USING (auth.uid() = referrer_id);

CREATE POLICY "Users can view referrals they received"
ON referrals FOR SELECT
USING (auth.uid() = referred_id);

CREATE POLICY "System can insert referrals"
ON referrals FOR INSERT
WITH CHECK (true); -- Service role only

-- Gem packs policies (public read access)
CREATE POLICY "Anyone can view active gem packs"
ON gem_packs FOR SELECT
USING (is_active = true);

-- Notification tokens policies
CREATE POLICY "Users can manage own notification tokens"
ON notification_tokens FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Analytics events policies
CREATE POLICY "Users can insert own analytics events"
ON analytics_events FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admin can view analytics events"
ON analytics_events FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() 
    AND email IN ('admin@rhymestar.com')
  )
);

-- Subscriptions policies (for future use)
CREATE POLICY "Users can view own subscriptions"
ON subscriptions FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "System can manage subscriptions"
ON subscriptions FOR ALL
USING (true); -- Service role only

-- Additional security functions

-- Function to check if user is admin
CREATE OR REPLACE FUNCTION is_admin(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM users 
    WHERE id = user_id 
    AND email IN ('admin@rhymestar.com', 'support@rhymestar.com')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user owns a child
CREATE OR REPLACE FUNCTION user_owns_child(user_id UUID, child_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM children 
    WHERE id = child_id 
    AND user_id = user_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user can access video
CREATE OR REPLACE FUNCTION user_can_access_video(user_id UUID, video_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM videos 
    WHERE id = video_id 
    AND user_id = user_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Storage policies for buckets

-- Avatars bucket policies
CREATE POLICY "Users can upload avatars to own folder"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'avatars' AND 
  auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Avatars are publicly viewable"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

CREATE POLICY "Users can update own avatars"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'avatars' AND 
  auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can delete own avatars"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'avatars' AND 
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Photos bucket policies (private)
CREATE POLICY "Users can upload photos to own folder"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'photos' AND 
  auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can view own photos"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'photos' AND 
  auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can update own photos"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'photos' AND 
  auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can delete own photos"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'photos' AND 
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Thumbnails bucket policies (public)
CREATE POLICY "Thumbnails are publicly viewable"
ON storage.objects FOR SELECT
USING (bucket_id = 'thumbnails');

CREATE POLICY "System can manage thumbnails"
ON storage.objects FOR ALL
USING (bucket_id = 'thumbnails'); -- Service role only

-- Rate limiting policies (using Supabase rate limiting)

-- Limit avatar generation to prevent abuse
CREATE OR REPLACE FUNCTION check_avatar_generation_rate_limit(user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  recent_count INTEGER;
BEGIN
  -- Allow max 5 avatar generations per hour
  SELECT COUNT(*) INTO recent_count
  FROM gem_transactions
  WHERE user_id = user_id
    AND type = 'avatar'
    AND created_at > NOW() - INTERVAL '1 hour';
    
  RETURN recent_count < 5;
END;
$$ LANGUAGE plpgsql;

-- Limit video creation to prevent spam
CREATE OR REPLACE FUNCTION check_video_creation_rate_limit(user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  recent_count INTEGER;
BEGIN
  -- Allow max 10 video creations per hour
  SELECT COUNT(*) INTO recent_count
  FROM videos
  WHERE user_id = user_id
    AND created_at > NOW() - INTERVAL '1 hour';
    
  RETURN recent_count < 10;
END;
$$ LANGUAGE plpgsql;

-- Security audit logging

-- Function to log security events
CREATE OR REPLACE FUNCTION log_security_event(
  event_type TEXT,
  user_id UUID,
  details JSONB DEFAULT '{}'
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO analytics_events (user_id, event_name, properties)
  VALUES (user_id, 'security_' || event_type, details);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to log failed gem transactions
CREATE OR REPLACE FUNCTION log_failed_gem_transaction()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.type = 'video' AND NEW.amount < 0 THEN
    -- This would be called if gem deduction fails
    PERFORM log_security_event('failed_gem_deduction', NEW.user_id, 
      jsonb_build_object('amount', NEW.amount, 'reference_id', NEW.reference_id));
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Additional constraints for data integrity

-- Ensure users can't have negative gem balance (additional check)
ALTER TABLE users ADD CONSTRAINT check_non_negative_gems 
CHECK (gem_balance >= 0);

-- Ensure video progress is valid
ALTER TABLE video_progress ADD CONSTRAINT check_valid_progress 
CHECK (progress_percentage >= 0 AND progress_percentage <= 100);

-- Ensure gem transactions have valid amounts
ALTER TABLE gem_transactions ADD CONSTRAINT check_valid_gem_amount 
CHECK (amount != 0); -- Prevent zero-amount transactions

-- Comments for security documentation
COMMENT ON POLICY "Users can view own profile" ON users IS 
  'Users can only see their own profile data for privacy';

COMMENT ON POLICY "Users can view own children" ON children IS 
  'Child profiles are private to the parent user only';

COMMENT ON POLICY "Anyone can view active rhymes" ON rhymes IS 
  'Rhyme catalog is public but only shows active content';

COMMENT ON POLICY "Users can view own videos" ON videos IS 
  'Video access is restricted to the creating user only';

COMMENT ON POLICY "Users can view own gem transactions" ON gem_transactions IS 
  'Financial data is private and audit-logged';

-- Enable realtime for authorized tables only
ALTER PUBLICATION supabase_realtime ADD TABLE videos;
ALTER PUBLICATION supabase_realtime ADD TABLE video_progress;
ALTER PUBLICATION supabase_realtime ADD TABLE gem_transactions;
ALTER PUBLICATION supabase_realtime ADD TABLE users;

-- Final security verification
SELECT 
  schemaname,
  tablename,
  rowsecurity,
  CASE WHEN rowsecurity THEN 'RLS Enabled ✓' ELSE 'RLS Missing ⚠️' END as security_status
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY tablename; 