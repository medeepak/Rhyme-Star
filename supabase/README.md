# 🚀 Supabase Setup Guide for Rhyme Star

## Prerequisites
- Node.js 16+ installed
- Supabase CLI installed: `npm install -g supabase`
- Supabase account at [supabase.com](https://supabase.com)

## 1. PROJECT INITIALIZATION

### Create New Supabase Project
```bash
# Create project on supabase.com dashboard
# Note down your project URL and anon key

# Initialize local Supabase
supabase init

# Link to your remote project
supabase link --project-ref your-project-ref
```

### Environment Setup
Create `.env.local`:
```env
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SERVICE_ROLE_KEY=your-service-role-key

# API Keys
OPENAI_API_KEY=your-openai-key
RUNWARE_API_KEY=your-runware-key
FIREBASE_SERVER_KEY=your-firebase-key

# AWS (for CloudFront/S3)
AWS_ACCESS_KEY_ID=your-aws-key
AWS_SECRET_ACCESS_KEY=your-aws-secret
AWS_BUCKET_NAME=rhyme-star-videos
AWS_CLOUDFRONT_DOMAIN=your-cloudfront-domain

# App Configuration
ENVIRONMENT=development
```

## 2. DATABASE SETUP

### Run Initial Migration
```bash
# Reset database to clean state
supabase db reset

# Apply migrations
supabase db push
```

### Verify Tables Created
```sql
-- Check if all tables exist
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public';
```

## 3. AUTHENTICATION SETUP

### Enable Auth Providers
1. Go to Authentication > Settings in Supabase Dashboard
2. Enable Email authentication
3. Configure OAuth providers (Google, Apple) if needed
4. Set site URL: `https://your-domain.com`
5. Add redirect URLs for mobile: 
   - `com.rhymestar.app://login-callback`
   - `rhymestar://login-callback`

### Auth Hooks (Optional)
```sql
-- Trigger to create user profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO users (id, email, gem_balance, referral_code)
  VALUES (
    NEW.id,
    NEW.email,
    200, -- Free gems
    generate_referral_code()
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();
```

## 4. STORAGE SETUP

### Create Storage Buckets
```sql
-- Avatar images bucket
INSERT INTO storage.buckets (id, name, public) 
VALUES ('avatars', 'avatars', true);

-- Child photos bucket (private)
INSERT INTO storage.buckets (id, name, public) 
VALUES ('photos', 'photos', false);

-- Video thumbnails bucket
INSERT INTO storage.buckets (id, name, public) 
VALUES ('thumbnails', 'thumbnails', true);
```

### Storage Policies
```sql
-- Avatar storage policies
CREATE POLICY "Users can upload avatars"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'avatars' AND 
  auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Avatars are publicly viewable"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

-- Photo storage policies  
CREATE POLICY "Users can upload photos"
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
```

## 5. EDGE FUNCTIONS SETUP

### Deploy Edge Functions
```bash
# Deploy all functions
supabase functions deploy

# Deploy specific function
supabase functions deploy process-avatar
supabase functions deploy queue-video
supabase functions deploy handle-payment
```

### Set Function Secrets
```bash
# Set API keys for functions
supabase secrets set OPENAI_API_KEY=your-key
supabase secrets set RUNWARE_API_KEY=your-key
supabase secrets set FIREBASE_SERVER_KEY=your-key
supabase secrets set AWS_ACCESS_KEY_ID=your-key
supabase secrets set AWS_SECRET_ACCESS_KEY=your-key
```

## 6. REAL-TIME SETUP

### Enable Real-time
```sql
-- Enable real-time for video progress
ALTER TABLE videos REPLICA IDENTITY FULL;
ALTER TABLE video_progress REPLICA IDENTITY FULL;
ALTER TABLE gem_transactions REPLICA IDENTITY FULL;

-- Create publication
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;
```

## 7. TESTING & VERIFICATION

### Test Database Connection
```bash
# Connect to database
supabase db connect

# Run test queries
SELECT COUNT(*) FROM users;
SELECT COUNT(*) FROM rhymes;
```

### Test Edge Functions
```bash
# Test avatar processing
curl -X POST https://your-project-ref.supabase.co/functions/v1/process-avatar \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"test": true}'
```

## 8. PRODUCTION CHECKLIST

- [ ] Enable RLS on all tables
- [ ] Set up custom SMTP for auth emails
- [ ] Configure rate limiting
- [ ] Set up monitoring alerts
- [ ] Enable audit logging
- [ ] Configure backup retention
- [ ] Set up SSL certificates
- [ ] Configure CORS properly
- [ ] Test all Edge Functions
- [ ] Verify storage policies
- [ ] Test real-time subscriptions
- [ ] Configure environment variables
- [ ] Set up error monitoring

## 9. COMMON ISSUES & SOLUTIONS

### Connection Issues
```bash
# Reset local environment
supabase stop
supabase start
```

### Migration Issues
```bash
# Generate new migration
supabase db diff -f your-migration-name

# Reset to specific migration
supabase db reset --debug
```

### Function Deployment Issues
```bash
# Check function logs
supabase functions logs process-avatar

# Deploy with debug
supabase functions deploy --debug
```

## 10. MONITORING & MAINTENANCE

### Regular Tasks
- Monitor function execution logs
- Check database performance metrics
- Review storage usage
- Monitor real-time connections
- Check error rates
- Review security events

### Performance Optimization
- Add database indexes for frequently queried columns
- Optimize RLS policies
- Cache frequently accessed data
- Monitor Edge Function cold starts
- Optimize storage policies

This guide ensures a complete, production-ready Supabase setup for Rhyme Star. 🌟 