-- Initial Rhyme Star Database Schema
-- Migration: 20240101000001_initial_schema.sql

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Custom types
CREATE TYPE gem_transaction_type AS ENUM ('purchase', 'referral', 'signup', 'avatar', 'video', 'refund');
CREATE TYPE video_status AS ENUM ('queued', 'processing', 'rendering', 'completed', 'failed', 'cancelled');
CREATE TYPE video_job_status AS ENUM ('pending', 'claimed', 'processing', 'completed', 'failed');

-- Generate referral code function
CREATE OR REPLACE FUNCTION generate_referral_code()
RETURNS TEXT AS $$
BEGIN
  RETURN upper(substring(md5(random()::text) from 1 for 8));
END;
$$ LANGUAGE plpgsql;

-- Users table (extends auth.users)
CREATE TABLE users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  display_name TEXT,
  gem_balance INTEGER DEFAULT 200 CHECK (gem_balance >= 0),
  total_gems_purchased INTEGER DEFAULT 0,
  total_gems_spent INTEGER DEFAULT 0,
  referral_code TEXT UNIQUE DEFAULT generate_referral_code(),
  referred_by UUID REFERENCES users(id),
  is_premium BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Children profiles
CREATE TABLE children (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL CHECK (length(name) >= 1 AND length(name) <= 50),
  photo_url TEXT,
  avatar_url TEXT,
  avatar_cached BOOLEAN DEFAULT FALSE,
  avatar_generated_at TIMESTAMP WITH TIME ZONE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Rhymes catalog
CREATE TABLE rhymes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  description TEXT,
  duration_seconds INTEGER NOT NULL CHECK (duration_seconds > 0),
  is_premium BOOLEAN DEFAULT FALSE,
  gem_cost INTEGER NOT NULL CHECK (gem_cost > 0),
  video_template_url TEXT,
  preview_url TEXT,
  thumbnail_url TEXT,
  language TEXT DEFAULT 'en',
  category TEXT DEFAULT 'nursery',
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Video processing table
CREATE TABLE videos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  child_id UUID REFERENCES children(id) ON DELETE CASCADE NOT NULL,
  rhyme_id UUID REFERENCES rhymes(id) ON DELETE CASCADE NOT NULL,
  status video_status DEFAULT 'queued',
  
  -- Runware API Integration
  runware_task_uuid TEXT UNIQUE,
  runware_model TEXT,
  runware_webhook_url TEXT,
  runware_cost_estimated DECIMAL(10,4),
  runware_cost_actual DECIMAL(10,4),
  
  -- Progress Tracking
  progress_percentage INTEGER DEFAULT 0 CHECK (progress_percentage >= 0 AND progress_percentage <= 100),
  current_stage TEXT DEFAULT 'initializing',
  estimated_completion TIMESTAMP WITH TIME ZONE,
  actual_completion TIMESTAMP WITH TIME ZONE,
  
  -- Video Output
  video_url TEXT,
  thumbnail_url TEXT,
  duration_seconds INTEGER,
  file_size_bytes BIGINT,
  
  -- Error Handling
  error_message TEXT,
  retry_count INTEGER DEFAULT 0,
  max_retries INTEGER DEFAULT 3,
  
  -- Metadata
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  started_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT valid_progress CHECK (
    (status = 'completed' AND progress_percentage = 100) OR
    (status != 'completed' AND progress_percentage < 100)
  )
);

-- Job Queue for reliable processing
CREATE TABLE video_jobs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  video_id UUID REFERENCES videos(id) ON DELETE CASCADE NOT NULL,
  priority INTEGER DEFAULT 1 CHECK (priority > 0),
  scheduled_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  processing_started_at TIMESTAMP WITH TIME ZONE,
  processing_node TEXT,
  status video_job_status DEFAULT 'pending',
  attempts INTEGER DEFAULT 0,
  max_attempts INTEGER DEFAULT 3,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Video progress tracking
CREATE TABLE video_progress (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  video_id UUID REFERENCES videos(id) ON DELETE CASCADE NOT NULL,
  stage TEXT NOT NULL,
  progress_percentage INTEGER NOT NULL CHECK (progress_percentage >= 0 AND progress_percentage <= 100),
  message TEXT,
  estimated_time_remaining INTERVAL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Gem transactions ledger
CREATE TABLE gem_transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  amount INTEGER NOT NULL,
  type gem_transaction_type NOT NULL,
  description TEXT,
  reference_id UUID, -- video_id, payment_id, etc.
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Referrals tracking
CREATE TABLE referrals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  referrer_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  referred_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  gems_awarded INTEGER DEFAULT 20,
  completed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Prevent duplicate referrals
  UNIQUE(referrer_id, referred_id)
);

-- Gem packs for IAP
CREATE TABLE gem_packs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sku TEXT UNIQUE NOT NULL, -- App store product ID
  name TEXT NOT NULL,
  description TEXT,
  gem_amount INTEGER NOT NULL CHECK (gem_amount > 0),
  price_usd DECIMAL(10,2) NOT NULL CHECK (price_usd > 0),
  bonus_gems INTEGER DEFAULT 0,
  is_popular BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User subscriptions (for future premium features)
CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  plan_id TEXT NOT NULL,
  status TEXT NOT NULL,
  current_period_start TIMESTAMP WITH TIME ZONE NOT NULL,
  current_period_end TIMESTAMP WITH TIME ZONE NOT NULL,
  cancel_at_period_end BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Notification tokens for push notifications
CREATE TABLE notification_tokens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  token TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  UNIQUE(user_id, token)
);

-- App analytics events
CREATE TABLE analytics_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  event_name TEXT NOT NULL,
  properties JSONB,
  session_id TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_users_referral_code ON users(referral_code);
CREATE INDEX idx_children_user_id ON children(user_id);
CREATE INDEX idx_children_active ON children(user_id) WHERE is_active = TRUE;
CREATE INDEX idx_videos_user_id ON videos(user_id);
CREATE INDEX idx_videos_status ON videos(status);
CREATE INDEX idx_videos_created_at ON videos(created_at);
CREATE INDEX idx_video_jobs_status ON video_jobs(status);
CREATE INDEX idx_video_jobs_priority ON video_jobs(priority DESC, created_at ASC);
CREATE INDEX idx_video_progress_video_id ON video_progress(video_id);
CREATE INDEX idx_gem_transactions_user_id ON gem_transactions(user_id);
CREATE INDEX idx_gem_transactions_created_at ON gem_transactions(created_at);
CREATE INDEX idx_referrals_referrer_id ON referrals(referrer_id);
CREATE INDEX idx_notification_tokens_user_id ON notification_tokens(user_id);
CREATE INDEX idx_analytics_events_created_at ON analytics_events(created_at);

-- Functions for business logic

-- Update user gem balance atomically
CREATE OR REPLACE FUNCTION update_gem_balance(
  p_user_id UUID,
  p_amount INTEGER,
  p_type gem_transaction_type,
  p_description TEXT,
  p_reference_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  current_balance INTEGER;
BEGIN
  -- Get current balance with row lock
  SELECT gem_balance INTO current_balance
  FROM users
  WHERE id = p_user_id
  FOR UPDATE;
  
  -- Check if user exists
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found: %', p_user_id;
  END IF;
  
  -- Check if sufficient balance for deductions
  IF p_amount < 0 AND current_balance + p_amount < 0 THEN
    RAISE EXCEPTION 'Insufficient gem balance. Required: %, Available: %', ABS(p_amount), current_balance;
  END IF;
  
  -- Update balance
  UPDATE users 
  SET 
    gem_balance = gem_balance + p_amount,
    total_gems_spent = CASE WHEN p_amount < 0 THEN total_gems_spent + ABS(p_amount) ELSE total_gems_spent END,
    total_gems_purchased = CASE WHEN p_amount > 0 AND p_type = 'purchase' THEN total_gems_purchased + p_amount ELSE total_gems_purchased END,
    updated_at = NOW()
  WHERE id = p_user_id;
  
  -- Record transaction
  INSERT INTO gem_transactions (user_id, amount, type, description, reference_id)
  VALUES (p_user_id, p_amount, p_type, p_description, p_reference_id);
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at triggers
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_children_updated_at BEFORE UPDATE ON children FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_videos_updated_at BEFORE UPDATE ON videos FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_video_jobs_updated_at BEFORE UPDATE ON video_jobs FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to handle new user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO users (id, email, gem_balance, referral_code)
  VALUES (
    NEW.id,
    NEW.email,
    200, -- Free gems for new users
    generate_referral_code()
  );
  
  -- Record signup gems transaction
  INSERT INTO gem_transactions (user_id, amount, type, description)
  VALUES (NEW.id, 200, 'signup', 'Welcome gems for new user');
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for new user signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Function to process referral
CREATE OR REPLACE FUNCTION process_referral(
  p_referred_user_id UUID,
  p_referral_code TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
  referrer_user_id UUID;
  referral_gems INTEGER := 20;
BEGIN
  -- Find referrer by referral code
  SELECT id INTO referrer_user_id
  FROM users
  WHERE referral_code = p_referral_code;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invalid referral code: %', p_referral_code;
  END IF;
  
  -- Prevent self-referral
  IF referrer_user_id = p_referred_user_id THEN
    RAISE EXCEPTION 'Cannot refer yourself';
  END IF;
  
  -- Check if referral already exists
  IF EXISTS (SELECT 1 FROM referrals WHERE referrer_id = referrer_user_id AND referred_id = p_referred_user_id) THEN
    RAISE EXCEPTION 'Referral already processed';
  END IF;
  
  -- Update referred user
  UPDATE users SET referred_by = referrer_user_id WHERE id = p_referred_user_id;
  
  -- Award gems to both users
  PERFORM update_gem_balance(referrer_user_id, referral_gems, 'referral', 'Referral bonus for inviting friend');
  PERFORM update_gem_balance(p_referred_user_id, referral_gems, 'referral', 'Welcome bonus from referral');
  
  -- Record referral
  INSERT INTO referrals (referrer_id, referred_id, gems_awarded)
  VALUES (referrer_user_id, p_referred_user_id, referral_gems);
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Insert initial rhymes data
INSERT INTO rhymes (title, description, duration_seconds, is_premium, gem_cost, language, category) VALUES
('Wheels on the Bus', 'Classic nursery rhyme about a bus journey', 45, TRUE, 100, 'en', 'nursery'),
('Baby Shark', 'Popular children song about shark family', 60, TRUE, 100, 'en', 'nursery'),
('Twinkle Twinkle Little Star', 'Traditional lullaby about a star', 30, FALSE, 50, 'en', 'lullaby'),
('Old MacDonald Had a Farm', 'Farm animals song with sounds', 50, FALSE, 50, 'en', 'nursery'),
('Row Row Row Your Boat', 'Gentle rowing boat song', 25, FALSE, 50, 'en', 'nursery'),
('If You''re Happy and You Know It', 'Interactive clapping song', 40, FALSE, 50, 'en', 'interactive'),
('Head Shoulders Knees and Toes', 'Body parts learning song', 35, FALSE, 50, 'en', 'educational'),
('The Itsy Bitsy Spider', 'Spider climbing adventure song', 30, FALSE, 50, 'en', 'nursery'),
('Mary Had a Little Lamb', 'Classic lamb following story', 25, FALSE, 50, 'en', 'nursery'),
('Baa Baa Black Sheep', 'Sheep wool sharing song', 20, FALSE, 50, 'en', 'nursery');

-- Insert gem pack options
INSERT INTO gem_packs (sku, name, description, gem_amount, price_usd, bonus_gems, is_popular) VALUES
('gems_100', 'Starter Pack', '100 gems to get started', 100, 9.99, 0, FALSE),
('gems_250', 'Popular Pack', '250 gems with bonus', 250, 19.99, 50, TRUE),
('gems_500', 'Family Pack', '500 gems for families', 500, 34.99, 100, FALSE),
('gems_1000', 'Mega Pack', '1000 gems with big bonus', 1000, 59.99, 300, FALSE),
('gems_2500', 'Ultimate Pack', '2500 gems maximum value', 2500, 99.99, 1000, FALSE);

-- Add comments for documentation
COMMENT ON TABLE users IS 'User profiles extending Supabase auth.users';
COMMENT ON TABLE children IS 'Child profiles for personalized content';
COMMENT ON TABLE rhymes IS 'Available nursery rhymes catalog';
COMMENT ON TABLE videos IS 'User-generated personalized videos';
COMMENT ON TABLE video_jobs IS 'Background job queue for video processing';
COMMENT ON TABLE gem_transactions IS 'Complete audit trail of gem usage';
COMMENT ON TABLE referrals IS 'User referral tracking and rewards';

-- Enable Row Level Security (RLS) on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE children ENABLE ROW LEVEL SECURITY;
ALTER TABLE videos ENABLE ROW LEVEL SECURITY;
ALTER TABLE video_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE gem_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;

-- Note: RLS policies will be added in the next migration 