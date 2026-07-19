final class UserProfile {
  const UserProfile({required this.id, required this.displayName, this.email});

  final String id;
  final String displayName;
  final String? email;
}

abstract interface class AuthService {
  Stream<UserProfile?> get authStateChanges;
  Future<UserProfile> signInWithGoogle();
  Future<UserProfile> signInWithApple();
  Future<void> signOut();
  Future<void> deleteAccount();
}

abstract interface class UserDataRepository {
  Future<void> saveFavorite(String userId, String foodId);
  Future<void> removeFavorite(String userId, String foodId);
  Future<Set<String>> loadFavorites(String userId);
  Future<void> saveDecision(String userId, Map<String, Object?> decision);
  Future<List<Map<String, Object?>>> loadDecisionHistory(String userId);
}

abstract interface class SubscriptionService {
  Stream<bool> get premiumStatus;
  Future<void> purchasePremiumMonthly();
  Future<void> purchasePremiumYearly();
  Future<void> restorePurchases();
}

abstract interface class NotificationService {
  Future<bool> requestPermission();
  Future<void> registerDeviceToken(String userId);
  Future<void> unregisterDeviceToken(String userId);
}

abstract interface class LocationService {
  Future<bool> requestPermission();
  Future<({double latitude, double longitude})?> currentPosition();
}

abstract interface class RestaurantRepository {
  Future<List<Map<String, Object?>>> nearbyRestaurants({
    required double latitude,
    required double longitude,
    required double radiusKm,
  });
}
