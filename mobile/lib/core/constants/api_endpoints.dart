class ApiEndpoints {
  // Live Render Backend Gateway URL
  static const String baseUrl = 'https://nearo-backend-k4by.onrender.com/api/v1';

  // Fallback / Alternate domain
  static const String fallbackBaseUrl = 'https://nearo.asiverticals.me/api/v1';

  // Clerk Authentication Configuration
  static const String clerkPublishableKey =
      'pk_test_dHJ1c3Rpbmctc2F0eXItOTMyMC5jbGVyay5hY2NvdW50cy5kZXYk';

  // Auth Routes
  static const String sendOtp = '/auth/otp/send';
  static const String verifyOtp = '/auth/otp/verify';
  static const String me = '/auth/me';
  static const String deleteAccount = '/auth/account';

  // Posts & Feed Routes
  static const String feed = '/posts/feed';
  static const String posts = '/posts';
  static const String createPost = '/posts';

  // Location & Geofencing
  static const String syncLocation = '/location/sync';

  // Civic SOS & Emergency Dispatch
  static const String sosBroadcast = '/sos/broadcast';
  static const String sosTrigger = '/sos/trigger';
  static const String activeSos = '/sos/active';

  // Monetization & Hyperlocal Ads
  static const String verifyPurchase = '/subscriptions/verify-purchase';
  static const String createSubscriptionOrder = '/subscriptions/create-order';
  static const String subscriptionTiers = '/subscriptions/tiers';
  static const String admobConfig = '/subscriptions/admob-config';
  static const String nearbyAds = '/ads/nearby';

  // Health
  static const String health = '/health';
}
