# Rhyme Star - World-Class Architecture Plan 🏗️

## 1. ARCHITECTURAL OVERVIEW

### **System Architecture**
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Flutter App   │    │   Supabase      │    │   External APIs │
│   (Mobile)      │◄──►│   Backend       │◄──►│   & Services    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
│                      │                      │
├─ State Management    ├─ Authentication      ├─ GPT-4o (Avatars)
├─ Navigation          ├─ Database           ├─ Kling API (Videos)
├─ Local Storage       ├─ File Storage       ├─ OpenAI (Moderation)
├─ Media Handling      ├─ Real-time Subs     ├─ AWS S3/CloudFront
└─ Payment Integration └─ Edge Functions     └─ Firebase Analytics
```

### **Data Flow Architecture**
```
Photo Upload → Content Safety → Avatar Gen → Cache → Video Selection 
     ↓              ↓             ↓          ↓           ↓
User Storage → AI Processing → Supabase → Reuse → Queue Processing
     ↓              ↓             ↓          ↓           ↓
Local Cache → Gem Deduction → Server Store → UI Update → Background Job
```

## 2. BACKEND ARCHITECTURE (Supabase)

### **Database Schema Design**

```sql
-- Core Tables
users (
  id: uuid PRIMARY KEY,
  email: text,
  created_at: timestamp,
  gem_balance: integer DEFAULT 200,
  referral_code: text UNIQUE,
  referred_by: uuid REFERENCES users(id)
)

children (
  id: uuid PRIMARY KEY,
  user_id: uuid REFERENCES users(id),
  name: text,
  photo_url: text,
  avatar_url: text,
  avatar_cached: boolean DEFAULT false,
  created_at: timestamp
)

rhymes (
  id: uuid PRIMARY KEY,
  title: text,
  description: text,
  duration: integer,
  is_premium: boolean,
  gem_cost: integer,
  video_template_url: text,
  preview_url: text,
  language: text DEFAULT 'en'
)

videos (
  id: uuid PRIMARY KEY,
  user_id: uuid REFERENCES users(id),
  child_id: uuid REFERENCES children(id),
  rhyme_id: uuid REFERENCES rhymes(id),
  status: text CHECK (status IN ('queued', 'processing', 'completed', 'failed')),
  kling_job_id: text,
  video_url: text,
  estimated_completion: timestamp,
  created_at: timestamp,
  completed_at: timestamp
)

gem_transactions (
  id: uuid PRIMARY KEY,
  user_id: uuid REFERENCES users(id),
  amount: integer,
  type: text CHECK (type IN ('purchase', 'referral', 'signup', 'avatar', 'video')),
  description: text,
  created_at: timestamp
)

referrals (
  id: uuid PRIMARY KEY,
  referrer_id: uuid REFERENCES users(id),
  referred_id: uuid REFERENCES users(id),
  gems_awarded: integer DEFAULT 20,
  created_at: timestamp
)
```

### **Supabase Edge Functions**

```typescript
// 1. process-avatar (GPT-4o Integration)
// 2. queue-video (Kling API Integration)
// 3. handle-payment (IAP Verification)
// 4. process-referral (Referral Logic)
// 5. content-moderation (OpenAI + Safety)
```

### **Row Level Security (RLS) Policies**
- Users can only access their own data
- Videos visible to creators only
- Gem transactions auditable by user
- Admin roles for content management

## 3. FRONTEND ARCHITECTURE (Flutter)

### **Project Structure**
```
lib/
├── src/
│   ├── core/
│   │   ├── constants/
│   │   ├── errors/
│   │   ├── network/
│   │   ├── utils/
│   │   └── themes/
│   ├── data/
│   │   ├── datasources/
│   │   ├── models/
│   │   └── repositories/
│   ├── domain/
│   │   ├── entities/
│   │   ├── repositories/
│   │   └── usecases/
│   ├── presentation/
│   │   ├── pages/
│   │   ├── widgets/
│   │   ├── providers/
│   │   └── utils/
│   └── main.dart
```

### **State Management Architecture (Riverpod)**
```dart
// Core Providers
authProvider              // User authentication state
gemBalanceProvider       // Real-time gem balance
childProfileProvider     // Child data management
videoQueueProvider       // Video processing queue
rhymeCatalogProvider     // Available rhymes
notificationProvider     // Push notifications

// Feature Providers
avatarGenerationProvider // Avatar creation flow
videoCreationProvider    // Video generation flow
paymentProvider          // IAP handling
referralProvider         // Referral system
```

### **Navigation Structure (GoRouter)**
```dart
// Route Tree
/ (splash) → /onboarding → /auth → /home
├── /child-setup
├── /avatar-creation
├── /rhyme-selection
├── /video-queue
├── /video-player
├── /gem-store
├── /settings
└── /referral
```

## 4. DEVELOPMENT PHASES

### **Phase 1: Foundation (Week 1-2)**
**Backend:**
- Supabase project setup
- Database schema implementation
- Authentication system
- Basic RLS policies
- Gem transaction system

**Frontend:**
- Flutter project structure
- Navigation setup (GoRouter)
- State management (Riverpod)
- Theme system
- Basic screens (splash, auth, home)

### **Phase 2: Core Features (Week 3-5)**
**Backend:**
- Edge function: Content moderation
- Edge function: Avatar processing (GPT-4o)
- File storage setup
- Referral system logic

**Frontend:**
- Photo upload & validation
- Child profile management
- Avatar generation UI
- Gem balance display
- Basic error handling

### **Phase 3: Video System (Week 6-8)**
**Backend:**
- Edge function: Video queue management
- Kling API integration
- AWS S3 + CloudFront setup
- Background job processing
- Push notification system

**Frontend:**
- Rhyme catalog display
- Video queue management
- Progress tracking
- Video player (HLS)
- Notification handling

### **Phase 4: Monetization (Week 9-10)**
**Backend:**
- IAP validation system
- Gem purchase logic
- Payment processing

**Frontend:**
- IAP integration (Apple/Google)
- Gem store UI
- Purchase restoration
- Premium content gating

### **Phase 5: Polish & Launch (Week 11-12)**
**Backend:**
- Performance optimization
- Error monitoring
- Analytics integration
- Load testing

**Frontend:**
- UI/UX refinement
- Analytics tracking
- Error boundaries
- App store optimization

## 5. TECHNICAL IMPLEMENTATION DETAILS

### **Content Safety Pipeline**
```dart
1. On-device face detection (ML Kit)
2. Image preprocessing & validation
3. OpenAI moderation API call
4. Server-side safety scoring
5. Approval/rejection workflow
```

### **Video Processing Queue**
```typescript
// Edge Function: queue-video
1. Validate gem balance
2. Deduct gems atomically
3. Create video record (status: 'queued')
4. Submit to Kling API
5. Store job ID for tracking
6. Return estimated completion time
```

### **Real-time Updates**
```dart
// Supabase real-time subscriptions
- Gem balance changes
- Video status updates
- Referral notifications
- System announcements
```

### **Caching Strategy**
```dart
// Multi-level caching
Local (Hive):     User preferences, UI state
Memory (Riverpod): Active data, navigation state
Server (Supabase): Generated avatars, video metadata
CDN (CloudFront): Video files, static assets
```

## 6. SECURITY & PRIVACY

### **Data Protection**
- End-to-end encryption for sensitive data
- COPPA compliance for children's data
- GDPR compliance for EU users
- Minimal data collection principle

### **API Security**
- JWT authentication
- Rate limiting on Edge Functions
- Input validation & sanitization
- SQL injection prevention (RLS)

### **Content Safety**
- Multi-layer content moderation
- Age-appropriate avatar generation
- Safe video content validation
- Parental controls

## 7. SCALABILITY CONSIDERATIONS

### **Database Optimization**
- Proper indexing strategy
- Connection pooling
- Read replicas for heavy queries
- Automated backups

### **Media Processing**
- CDN distribution (CloudFront)
- Video compression optimization
- Progressive loading
- Bandwidth adaptation

### **Cost Optimization**
- S3 lifecycle policies (30-day retention)
- Edge Function execution limits
- Database connection management
- API rate limiting

## 8. MONITORING & ANALYTICS

### **Performance Monitoring**
- Supabase built-in metrics
- Firebase Performance
- Custom error tracking
- API response times

### **Business Analytics**
- User acquisition funnels
- Gem purchase conversions
- Video generation metrics
- Referral tracking

### **User Experience**
- Crash reporting
- User behavior flows
- Feature usage statistics
- Customer satisfaction metrics

## 9. TESTING STRATEGY

### **Backend Testing**
- Unit tests for Edge Functions
- Integration tests for API endpoints
- Load testing for video processing
- Security penetration testing

### **Frontend Testing**
- Widget testing for UI components
- Integration testing for user flows
- Golden tests for visual consistency
- Performance testing on devices

### **End-to-End Testing**
- Complete user journey testing
- Payment flow testing
- Video generation pipeline testing
- Cross-platform compatibility

## 10. DEPLOYMENT & CI/CD

### **Backend Deployment**
- Supabase CLI for migrations
- Edge Functions auto-deployment
- Environment-based configurations
- Database migration strategies

### **Frontend Deployment**
- GitHub Actions for CI/CD
- Automated testing pipeline
- App Store/Play Store deployment
- Beta testing workflows

## 11. COMPLETE REQUIREMENTS SUMMARY

### **Core Features:**
- **Photo Upload & Avatar Generation**: 20 gems via GPT-4o
- **Video Creation**: 50-100 gems via Kling API
- **Gem Economy**: 10 gems = $1, 200 free gems at signup
- **Referral System**: 20 gems for both referrer and referred friend
- **Content Library**: 10 nursery rhymes (2 premium, 8 standard)

### **Technical Stack:**
- **Frontend**: Flutter + Riverpod + GoRouter + Hive
- **Backend**: Supabase (auth, database, real-time, edge functions)
- **AI Services**: GPT-4o (avatars), Kling API (videos), OpenAI (moderation)
- **Storage**: AWS S3 + CloudFront (30-day retention, HLS streaming)
- **Payments**: Apple IAP + Google Play Billing
- **Analytics**: Firebase

### **Content & Pricing:**
- **Premium Rhymes** (100 gems): "Wheels on the Bus", "Baby Shark"
- **Standard Rhymes** (50 gems): 8 other nursery rhymes
- **Avatar Generation**: 20 gems (server-cached, reusable)
- **No spending/generation limits**

### **Video Processing:**
- Async background processing (minutes to hours)
- Push notifications when complete
- Multiple videos in processing queue
- Estimated completion times
- Allow app closure during processing

This comprehensive architecture plan provides the foundation for building a scalable, secure, and user-friendly Rhyme Star application. 🚀 