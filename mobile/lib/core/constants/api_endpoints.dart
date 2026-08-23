class ApiEndpoints {
  // Production Base Gateway URL
  static const String baseUrl = 'https://nearo.asiverticals.me/api/v1';

  // Auth Routes
  static const String sendOtp = '/auth/otp/send';
  static const String verifyOtp = '/auth/otp/verify';
  static const String me = '/auth/me';
  static const String deleteAccount = '/auth/account';

  // Posts & Feed Routes
  static const String feed = '/posts/feed';
  static const String createPost = '/posts';

  // Location & Geofencing
  static const String syncLocation = '/location/sync';

  // Civic SOS & Emergency Dispatch
  static const String sosBroadcast = '/sos/broadcast';
  static const String activeSos = '/sos/active';

  // Monetization & Hyperlocal Ads
  static const String createSubscriptionOrder = '/subscriptions/create-order';
  static const String subscriptionTiers = '/subscriptions/tiers';
  static const String nearbyAds = '/ads/nearby';

  // Health
  static const String health = '/health';
}
