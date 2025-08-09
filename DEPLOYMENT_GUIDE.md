# 🚀 Deployment Guide for Rhyme Star

## 📋 OVERVIEW

This guide covers the complete deployment process for Rhyme Star, from development to production, including CI/CD pipelines, monitoring, and maintenance.

## 🏗️ INFRASTRUCTURE ARCHITECTURE

### Production Stack
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Mobile Apps   │    │   Supabase      │    │   External APIs │
│   (iOS/Android) │◄──►│   Production    │◄──►│   & Services    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │                       │
        ├─ App Store            ├─ PostgreSQL           ├─ OpenAI GPT-4o
        ├─ Google Play          ├─ Edge Functions       ├─ Runware API
        └─ TestFlight           ├─ Storage Buckets      ├─ Firebase Analytics
                               ├─ Real-time Subs       └─ CloudFront CDN
                               └─ Row Level Security
```

## 🌍 ENVIRONMENTS

### 1. Development Environment
```yaml
# .env.development
ENVIRONMENT=development
SUPABASE_URL=https://dev-rhymestar.supabase.co
SUPABASE_ANON_KEY=eyJ...dev-key
SUPABASE_SERVICE_ROLE_KEY=eyJ...dev-service-key

# API Keys (Development/Sandbox)
OPENAI_API_KEY=<set-in-secrets>
RUNWARE_API_KEY=rw_...dev-key
FIREBASE_SERVER_KEY=AAAA...dev-key

# AWS (Development)
AWS_ACCESS_KEY_ID=AKIA...dev
AWS_SECRET_ACCESS_KEY=...dev
AWS_BUCKET_NAME=rhyme-star-dev-videos
AWS_CLOUDFRONT_DOMAIN=dev-cdn.rhymestar.com

# App Configuration
APP_NAME=Rhyme Star Dev
APP_ID=com.rhymestar.dev
VERSION_NAME=1.0.0-dev
BUILD_NUMBER=1
```

### 2. Staging Environment
```yaml
# .env.staging
ENVIRONMENT=staging
SUPABASE_URL=https://staging-rhymestar.supabase.co
SUPABASE_ANON_KEY=eyJ...staging-key
SUPABASE_SERVICE_ROLE_KEY=eyJ...staging-service-key

# API Keys (Staging)
OPENAI_API_KEY=<set-in-secrets>
RUNWARE_API_KEY=rw_...staging-key
FIREBASE_SERVER_KEY=AAAA...staging-key

# AWS (Staging)
AWS_ACCESS_KEY_ID=AKIA...staging
AWS_SECRET_ACCESS_KEY=...staging
AWS_BUCKET_NAME=rhyme-star-staging-videos
AWS_CLOUDFRONT_DOMAIN=staging-cdn.rhymestar.com

# App Configuration
APP_NAME=Rhyme Star Staging
APP_ID=com.rhymestar.staging
VERSION_NAME=1.0.0-staging
BUILD_NUMBER=auto-increment
```

### 3. Production Environment
```yaml
# .env.production
ENVIRONMENT=production
SUPABASE_URL=https://rhymestar.supabase.co
SUPABASE_ANON_KEY=eyJ...prod-key
SUPABASE_SERVICE_ROLE_KEY=eyJ...prod-service-key

# API Keys (Production)
OPENAI_API_KEY=<set-in-secrets>
RUNWARE_API_KEY=rw_...prod-key
FIREBASE_SERVER_KEY=AAAA...prod-key

# AWS (Production)
AWS_ACCESS_KEY_ID=AKIA...prod
AWS_SECRET_ACCESS_KEY=...prod
AWS_BUCKET_NAME=rhyme-star-videos
AWS_CLOUDFRONT_DOMAIN=cdn.rhymestar.com

# App Configuration
APP_NAME=Rhyme Star
APP_ID=com.rhymestar.app
VERSION_NAME=1.0.0
BUILD_NUMBER=auto-increment
```

## 🔧 CI/CD PIPELINE

### GitHub Actions Workflow
```yaml
# .github/workflows/ci-cd.yml
name: CI/CD Pipeline
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
      
      - name: Install dependencies
        run: flutter pub get
      
      - name: Run tests
        run: flutter test
      
      - name: Analyze code
        run: flutter analyze
      
      - name: Check formatting
        run: dart format --output=none --set-exit-if-changed .

  build-android:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - uses: actions/setup-java@v3
        with:
          distribution: 'zulu'
          java-version: '17'
      
      - name: Setup environment
        run: |
          echo "${{ secrets.ENV_PRODUCTION }}" > .env
          echo "${{ secrets.ANDROID_KEYSTORE }}" | base64 -d > android/keystore.jks
      
      - name: Build Android APK
        run: flutter build apk --release --dart-define-from-file=.env
      
      - name: Build Android App Bundle
        run: flutter build appbundle --release --dart-define-from-file=.env
      
      - name: Upload to Play Console
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT }}
          packageName: com.rhymestar.app
          releaseFiles: build/app/outputs/bundle/release/app-release.aab
          track: internal

  build-ios:
    needs: test
    runs-on: macos-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      
      - name: Setup iOS certificates
        uses: apple-actions/import-codesign-certs@v1
        with:
          p12-file-base64: ${{ secrets.IOS_CERTIFICATES }}
          p12-password: ${{ secrets.IOS_CERTIFICATE_PASSWORD }}
      
      - name: Setup provisioning profiles
        uses: apple-actions/download-provisioning-profiles@v1
        with:
          bundle-id: com.rhymestar.app
          issuer-id: ${{ secrets.APPSTORE_ISSUER_ID }}
          api-key-id: ${{ secrets.APPSTORE_API_KEY_ID }}
          api-private-key: ${{ secrets.APPSTORE_API_PRIVATE_KEY }}
      
      - name: Build iOS
        run: |
          echo "${{ secrets.ENV_PRODUCTION }}" > .env
          flutter build ios --release --dart-define-from-file=.env --no-codesign
          cd ios && xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release -destination generic/platform=iOS -archivePath Runner.xcarchive archive
      
      - name: Upload to TestFlight
        uses: apple-actions/upload-testflight-build@v1
        with:
          app-path: ios/Runner.xcarchive
          issuer-id: ${{ secrets.APPSTORE_ISSUER_ID }}
          api-key-id: ${{ secrets.APPSTORE_API_KEY_ID }}
          api-private-key: ${{ secrets.APPSTORE_API_PRIVATE_KEY }}

  deploy-backend:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3
      - uses: supabase/setup-cli@v1
      
      - name: Deploy database migrations
        run: |
          supabase link --project-ref ${{ secrets.SUPABASE_PROJECT_REF }}
          supabase db push
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
      
      - name: Deploy Edge Functions
        run: |
          supabase functions deploy process-avatar
          supabase functions deploy queue-video
          supabase functions deploy handle-payment
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
```

## 📱 APP STORE DEPLOYMENT

### iOS App Store
```yaml
# ios/fastlane/Fastfile
default_platform(:ios)

platform :ios do
  desc "Build and upload to TestFlight"
  lane :beta do
    build_app(
      scheme: "Runner",
      workspace: "Runner.xcworkspace",
      configuration: "Release",
      export_method: "app-store"
    )
    
    upload_to_testflight(
      skip_waiting_for_build_processing: true,
      changelog: ENV["CHANGELOG"] || "Bug fixes and improvements"
    )
  end
  
  desc "Deploy to App Store"
  lane :release do
    build_app(
      scheme: "Runner",
      workspace: "Runner.xcworkspace",
      configuration: "Release",
      export_method: "app-store"
    )
    
    upload_to_app_store(
      submit_for_review: false,
      force: true,
      metadata_path: "./metadata",
      screenshots_path: "./screenshots"
    )
  end
end
```

### Android Play Store
```yaml
# android/fastlane/Fastfile
default_platform(:android)

platform :android do
  desc "Build and upload to Play Console Internal Track"
  lane :internal do
    gradle(task: "bundleRelease")
    
    upload_to_play_store(
      track: "internal",
      aab: "app/build/outputs/bundle/release/app-release.aab",
      json_key: ENV["GOOGLE_PLAY_JSON_KEY_PATH"]
    )
  end
  
  desc "Promote to Production"
  lane :production do
    upload_to_play_store(
      track: "production",
      track_promote_to: "production",
      skip_upload_apk: true,
      skip_upload_aab: true
    )
  end
end
```

## 🗄️ DATABASE DEPLOYMENT

### Migration Strategy
```sql
-- migrations/deploy.sql
-- Production deployment script

BEGIN;

-- 1. Create backup
CREATE SCHEMA IF NOT EXISTS backup_$(date +%Y%m%d);
-- Backup critical tables
CREATE TABLE backup_$(date +%Y%m%d).users AS SELECT * FROM users;
CREATE TABLE backup_$(date +%Y%m%d).videos AS SELECT * FROM videos;
CREATE TABLE backup_$(date +%Y%m%d).gem_transactions AS SELECT * FROM gem_transactions;

-- 2. Run migrations
\i 20240101000001_initial_schema.sql;
\i 20240101000002_rls_policies.sql;

-- 3. Verify data integrity
DO $$
DECLARE
  user_count INTEGER;
  video_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO user_count FROM users;
  SELECT COUNT(*) INTO video_count FROM videos;
  
  IF user_count = 0 THEN
    RAISE EXCEPTION 'Data migration failed: No users found';
  END IF;
  
  RAISE NOTICE 'Migration successful: % users, % videos', user_count, video_count;
END $$;

COMMIT;
```

### Rollback Strategy
```sql
-- migrations/rollback.sql
-- Emergency rollback script

BEGIN;

-- Restore from backup if needed
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO public;

-- Restore tables from backup
CREATE TABLE users AS SELECT * FROM backup_$(date +%Y%m%d).users;
CREATE TABLE videos AS SELECT * FROM backup_$(date +%Y%m%d).videos;
CREATE TABLE gem_transactions AS SELECT * FROM backup_$(date +%Y%m%d).gem_transactions;

-- Restore indexes and constraints
\i previous_schema.sql;

COMMIT;
```

## 📊 MONITORING & ANALYTICS

### Supabase Dashboard Alerts
```json
{
  "alerts": [
    {
      "name": "High Error Rate",
      "condition": "error_rate > 5%",
      "channels": ["email", "slack"],
      "recipients": ["team@rhymestar.com"]
    },
    {
      "name": "Database Connection Issues",
      "condition": "connection_count > 80",
      "channels": ["slack"],
      "severity": "critical"
    },
    {
      "name": "Edge Function Failures",
      "condition": "function_error_rate > 10%",
      "channels": ["email"],
      "functions": ["process-avatar", "queue-video"]
    }
  ]
}
```

### Firebase Analytics Setup
```dart
// lib/src/core/analytics/analytics_service.dart
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  
  static Future<void> logEvent(String name, Map<String, Object> parameters) async {
    await _analytics.logEvent(name: name, parameters: parameters);
  }
  
  static Future<void> setUserId(String userId) async {
    await _analytics.setUserId(id: userId);
  }
  
  static Future<void> setUserProperty(String name, String value) async {
    await _analytics.setUserProperty(name: name, value: value);
  }
  
  // App Events
  static Future<void> logAppOpen() async {
    await _analytics.logAppOpen();
  }
  
  static Future<void> logSignUp(String method) async {
    await _analytics.logSignUp(signUpMethod: method);
  }
  
  static Future<void> logLogin(String method) async {
    await _analytics.logLogin(loginMethod: method);
  }
  
  // Business Events
  static Future<void> logAvatarGenerated(String childId, int gemsCost) async {
    await logEvent('avatar_generated', {
      'child_id': childId,
      'gems_cost': gemsCost,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  static Future<void> logVideoCreated(String rhymeId, int gemsCost) async {
    await logEvent('video_created', {
      'rhyme_id': rhymeId,
      'gems_cost': gemsCost,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  static Future<void> logPurchase(String productId, double price) async {
    await _analytics.logPurchase(
      currency: 'USD',
      value: price,
      parameters: {
        'product_id': productId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }
}
```

### Error Monitoring with Crashlytics
```dart
// lib/src/core/monitoring/crash_service.dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class CrashService {
  static Future<void> initialize() async {
    if (kDebugMode) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
    } else {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      
      // Pass all uncaught errors from the framework to Crashlytics
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      
      // Pass all uncaught asynchronous errors to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
  }
  
  static Future<void> recordError(dynamic exception, StackTrace? stack) async {
    await FirebaseCrashlytics.instance.recordError(
      exception,
      stack,
      fatal: false,
    );
  }
  
  static Future<void> setUserId(String userId) async {
    await FirebaseCrashlytics.instance.setUserId(userId);
  }
  
  static Future<void> setCustomKey(String key, Object value) async {
    await FirebaseCrashlytics.instance.setCustomKey(key, value);
  }
  
  static Future<void> log(String message) async {
    await FirebaseCrashlytics.instance.log(message);
  }
}
```

## 🔒 SECURITY CHECKLIST

### Pre-Deployment Security Audit
```bash
#!/bin/bash
# security-audit.sh

echo "🔒 Running Security Audit..."

# 1. Check for hardcoded secrets
echo "Checking for hardcoded secrets..."
grep -r "sk-" --exclude-dir=.git . && echo "❌ Found potential OpenAI keys" || echo "✅ No OpenAI keys found"
grep -r "rw_" --exclude-dir=.git . && echo "❌ Found potential Runware keys" || echo "✅ No Runware keys found"

# 2. Verify environment files are gitignored
if [ -f .env ]; then
  echo "❌ Environment file found in repo"
  exit 1
else
  echo "✅ No environment files in repo"
fi

# 3. Check Flutter security
flutter analyze --no-pub

# 4. Verify dependencies
flutter pub deps --check-updates

# 5. Check for debug code
grep -r "print(" lib/ && echo "❌ Found debug print statements" || echo "✅ No debug prints found"
grep -r "debugPrint(" lib/ && echo "⚠️ Found debugPrint statements" || echo "✅ No debugPrint found"

echo "✅ Security audit complete"
```

### Production Secrets Management
```yaml
# Required GitHub Secrets
secrets:
  # Supabase
  SUPABASE_PROJECT_REF: "your-project-ref"
  SUPABASE_ACCESS_TOKEN: "your-access-token"
  
  # Environment Files
  ENV_PRODUCTION: |
    ENVIRONMENT=production
    SUPABASE_URL=https://rhymestar.supabase.co
    SUPABASE_ANON_KEY=eyJ...
    # ... all production env vars
  
  # Android
  ANDROID_KEYSTORE: "base64-encoded-keystore"
  ANDROID_KEYSTORE_PASSWORD: "keystore-password"
  ANDROID_KEY_ALIAS: "upload-key"
  ANDROID_KEY_PASSWORD: "key-password"
  GOOGLE_PLAY_SERVICE_ACCOUNT: "json-service-account"
  
  # iOS
  IOS_CERTIFICATES: "base64-encoded-p12"
  IOS_CERTIFICATE_PASSWORD: "cert-password"
  APPSTORE_ISSUER_ID: "issuer-id"
  APPSTORE_API_KEY_ID: "api-key-id"
  APPSTORE_API_PRIVATE_KEY: "private-key"
```

## 📈 PERFORMANCE MONITORING

### Key Metrics to Monitor
```yaml
performance_metrics:
  app_performance:
    - app_start_time
    - screen_load_time
    - memory_usage
    - battery_usage
    - crash_rate
    - anr_rate
  
  backend_performance:
    - api_response_time
    - database_query_time
    - edge_function_execution_time
    - storage_upload_time
    - real_time_connection_count
  
  business_metrics:
    - daily_active_users
    - avatar_generation_rate
    - video_creation_rate
    - gem_purchase_conversion
    - user_retention_rate
    - churn_rate
```

### Performance Alerts
```json
{
  "performance_alerts": [
    {
      "metric": "app_start_time",
      "threshold": "> 3000ms",
      "severity": "warning"
    },
    {
      "metric": "api_response_time",
      "threshold": "> 5000ms",
      "severity": "critical"
    },
    {
      "metric": "crash_rate",
      "threshold": "> 1%",
      "severity": "critical"
    },
    {
      "metric": "video_generation_failure_rate",
      "threshold": "> 5%",
      "severity": "warning"
    }
  ]
}
```

## 🚨 INCIDENT RESPONSE

### Emergency Procedures
```markdown
# 🚨 Emergency Response Procedures

## Critical Issues (App Down/Data Loss)
1. **Immediate Response (0-15 minutes)**
   - Alert all team members
   - Assess scope of impact
   - Implement immediate mitigation

2. **Triage (15-60 minutes)**
   - Identify root cause
   - Determine rollback strategy
   - Execute recovery plan

3. **Recovery (1-4 hours)**
   - Implement fix or rollback
   - Verify system stability
   - Monitor for recurring issues

4. **Post-Mortem (24-48 hours)**
   - Document incident timeline
   - Identify prevention measures
   - Update monitoring/alerts

## Contact Information
- On-call Engineer: +1-xxx-xxx-xxxx
- Team Lead: team-lead@rhymestar.com
- Emergency Slack: #rhyme-star-emergency
```

## 📝 MAINTENANCE PROCEDURES

### Regular Maintenance Tasks
```bash
#!/bin/bash
# maintenance.sh - Weekly maintenance script

# 1. Database maintenance
echo "Running database maintenance..."
supabase db connect --execute "VACUUM ANALYZE;"

# 2. Clean up old video files (30+ days)
echo "Cleaning up old videos..."
# This would integrate with AWS lifecycle policies

# 3. Update dependencies
echo "Checking for dependency updates..."
flutter pub upgrade --dry-run

# 4. Security patches
echo "Checking for security updates..."
flutter doctor

# 5. Backup verification
echo "Verifying backups..."
# Verify Supabase automatic backups are working

echo "✅ Maintenance complete"
```

## 🎯 DEPLOYMENT CHECKLIST

### Pre-Deployment Checklist
- [ ] All tests passing
- [ ] Security audit completed
- [ ] Performance benchmarks met
- [ ] Database migrations tested
- [ ] Edge functions deployed to staging
- [ ] Mobile app tested on physical devices
- [ ] App store metadata updated
- [ ] Monitoring alerts configured
- [ ] Rollback plan prepared
- [ ] Team notified of deployment

### Post-Deployment Checklist
- [ ] App successfully deployed to stores
- [ ] Database migrations applied
- [ ] Edge functions responding correctly
- [ ] Real-time features working
- [ ] Analytics tracking properly
- [ ] Error rates within normal range
- [ ] Performance metrics stable
- [ ] User feedback monitored
- [ ] Team notified of completion

This deployment guide ensures a smooth, secure, and monitored production deployment for Rhyme Star! 🚀 