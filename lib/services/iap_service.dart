// ============================================================
// IN-APP PURCHASE SERVICE
// ============================================================
// This service handles Apple/Google in-app purchases.
// Currently commented out until App Store Connect is configured.
//
// TO ENABLE:
// 1. Add to pubspec.yaml:
//    in_app_purchase: ^3.1.13
//
// 2. Configure products in App Store Connect / Google Play Console
//
// 3. Uncomment the code below
//
// 4. Initialize in main.dart:
//    await IAPService.instance.initialize();
// ============================================================

import 'dart:async';
import 'currency_service.dart';

/// Product IDs - must match App Store Connect / Play Console exactly
class IAPProducts {
  // Chip Packs
  static const String chips100k = 'com.allin.chips_100k'; // $0.99  -> 100K chips
  static const String chips1m = 'com.allin.chips_1m'; // $4.99  -> 1M chips + 100K bonus
  static const String chips4m = 'com.allin.chips_4m'; // $9.99  -> 4M chips + 400K bonus (BEST)
  static const String chips12m = 'com.allin.chips_12m'; // $19.99 -> 12M chips + 1.2M bonus
  static const String chips40m = 'com.allin.chips_40m'; // $49.99 -> 40M chips + 4M bonus
  static const String chips120m = 'com.allin.chips_120m'; // $99.99 -> 120M chips + 12M bonus

  // Gem Packs
  static const String gems80 = 'com.allin.gems_80'; // $0.99  -> 80 gems
  static const String gems500 = 'com.allin.gems_500'; // $4.99  -> 500 gems + 50 bonus
  static const String gems1200 = 'com.allin.gems_1200'; // $9.99  -> 1200 gems + 120 bonus (BEST)
  static const String gems3000 = 'com.allin.gems_3000'; // $19.99 -> 3000 gems + 300 bonus
  static const String gems8000 = 'com.allin.gems_8000'; // $49.99 -> 8000 gems + 800 bonus
  static const String gems20000 = 'com.allin.gems_20000'; // $99.99 -> 20000 gems + 2000 bonus

  // Special Offers
  static const String starterPack = 'com.allin.starter_pack'; // $2.99 -> 1M chips + 200 gems
  static const String proPack = 'com.allin.pro_pack'; // $5.99 -> 5M chips + 500 gems + exclusive items

  // Subscriptions / Non-consumables
  static const String proPass = 'com.allin.pro_pass'; // $4.99 -> Pro Pass (non-consumable)

  /// All consumable product IDs
  static const List<String> consumables = [
    chips100k,
    chips1m,
    chips4m,
    chips12m,
    chips40m,
    chips120m,
    gems80,
    gems500,
    gems1200,
    gems3000,
    gems8000,
    gems20000,
    starterPack,
    proPack,
  ];

  /// All non-consumable product IDs
  static const List<String> nonConsumables = [
    proPass,
  ];

  /// All product IDs
  static List<String> get all => [...consumables, ...nonConsumables];

  /// Get reward for a product
  static Map<String, int> getReward(String productId) {
    switch (productId) {
      // Chips
      case chips100k:
        return {'chips': 100000};
      case chips1m:
        return {'chips': 1100000}; // 1M + 100K bonus
      case chips4m:
        return {'chips': 4400000}; // 4M + 400K bonus
      case chips12m:
        return {'chips': 13200000}; // 12M + 1.2M bonus
      case chips40m:
        return {'chips': 44000000}; // 40M + 4M bonus
      case chips120m:
        return {'chips': 132000000}; // 120M + 12M bonus

      // Gems
      case gems80:
        return {'gems': 80};
      case gems500:
        return {'gems': 550}; // 500 + 50 bonus
      case gems1200:
        return {'gems': 1320}; // 1200 + 120 bonus
      case gems3000:
        return {'gems': 3300}; // 3000 + 300 bonus
      case gems8000:
        return {'gems': 8800}; // 8000 + 800 bonus
      case gems20000:
        return {'gems': 22000}; // 20000 + 2000 bonus

      // Special packs
      case starterPack:
        return {'chips': 1000000, 'gems': 200};
      case proPack:
        return {'chips': 5000000, 'gems': 500};

      // Non-consumables return empty (handled separately)
      default:
        return {};
    }
  }
}

/*
// ============================================================
// UNCOMMENT BELOW WHEN READY TO IMPLEMENT IAP
// ============================================================

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/foundation.dart';

/// Singleton service for handling in-app purchases
class IAPService {
  static final IAPService _instance = IAPService._internal();
  static IAPService get instance => _instance;
  IAPService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  
  /// Available products from the store
  List<ProductDetails> products = [];
  
  /// Stream subscription for purchase updates
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  
  /// Whether the store is available
  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  /// Callback when purchase completes successfully
  Function(String productId, Map<String, int> reward)? onPurchaseSuccess;
  
  /// Callback when purchase fails
  Function(String error)? onPurchaseError;

  /// Initialize the IAP service - call in main.dart
  Future<void> initialize() async {
    _isAvailable = await _iap.isAvailable();
    
    if (!_isAvailable) {
      debugPrint('⚠️ IAP not available on this device');
      return;
    }

    // Listen to purchase updates
    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) => debugPrint('❌ IAP stream error: $error'),
    );

    // Load products
    await loadProducts();
  }

  /// Load available products from the store
  Future<void> loadProducts() async {
    if (!_isAvailable) return;

    final response = await _iap.queryProductDetails(IAPProducts.all.toSet());
    
    if (response.error != null) {
      debugPrint('❌ Failed to load products: ${response.error}');
      return;
    }

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('⚠️ Products not found: ${response.notFoundIDs}');
    }

    products = response.productDetails;
    debugPrint('✅ Loaded ${products.length} IAP products');
  }

  /// Purchase a product
  Future<bool> purchase(String productId) async {
    if (!_isAvailable) {
      onPurchaseError?.call('Store not available');
      return false;
    }

    final product = products.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw Exception('Product not found: $productId'),
    );

    final isConsumable = IAPProducts.consumables.contains(productId);
    
    final purchaseParam = PurchaseParam(productDetails: product);
    
    try {
      if (isConsumable) {
        await _iap.buyConsumable(purchaseParam: purchaseParam);
      } else {
        await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      }
      return true;
    } catch (e) {
      debugPrint('❌ Purchase failed: $e');
      onPurchaseError?.call(e.toString());
      return false;
    }
  }

  /// Handle purchase updates from the stream
  void _handlePurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          debugPrint('⏳ Purchase pending: ${purchase.productID}');
          break;
          
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _verifyAndDeliver(purchase);
          break;
          
        case PurchaseStatus.error:
          debugPrint('❌ Purchase error: ${purchase.error}');
          onPurchaseError?.call(purchase.error?.message ?? 'Purchase failed');
          _completePurchase(purchase);
          break;
          
        case PurchaseStatus.canceled:
          debugPrint('🚫 Purchase canceled: ${purchase.productID}');
          _completePurchase(purchase);
          break;
      }
    }
  }

  /// Verify purchase and deliver content
  Future<void> _verifyAndDeliver(PurchaseDetails purchase) async {
    // TODO: Add server-side receipt verification for production
    // For now, trust the client (not recommended for production!)
    
    final productId = purchase.productID;
    final reward = IAPProducts.getReward(productId);
    
    // Deliver the reward
    if (reward.containsKey('chips')) {
      await CurrencyService.addChips(reward['chips']!);
    }
    if (reward.containsKey('gems')) {
      await CurrencyService.addGems(reward['gems']!);
    }
    
    // Handle non-consumables (Pro Pass)
    if (productId == IAPProducts.proPass) {
      // TODO: Set pro pass status
      // await UserPreferences.setProPass(true);
    }
    
    debugPrint('✅ Delivered reward for ${purchase.productID}: $reward');
    onPurchaseSuccess?.call(productId, reward);
    
    _completePurchase(purchase);
  }

  /// Complete the purchase transaction
  Future<void> _completePurchase(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }

  /// Restore previous purchases (for non-consumables)
  Future<void> restorePurchases() async {
    if (!_isAvailable) return;
    await _iap.restorePurchases();
  }

  /// Get product details by ID
  ProductDetails? getProduct(String productId) {
    try {
      return products.firstWhere((p) => p.id == productId);
    } catch (_) {
      return null;
    }
  }

  /// Get localized price for a product
  String? getPrice(String productId) {
    return getProduct(productId)?.price;
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
  }
}

// ============================================================
// EXAMPLE USAGE IN SHOP_TAB.DART:
// ============================================================
//
// // In your CurrencyCard widget, wrap with GestureDetector:
// GestureDetector(
//   onTap: () async {
//     final success = await IAPService.instance.purchase(IAPProducts.chips1m);
//     if (success) {
//       // Purchase initiated - wait for callback
//     }
//   },
//   child: CurrencyCard(...),
// )
//
// // Set up callbacks (e.g., in initState):
// IAPService.instance.onPurchaseSuccess = (productId, reward) {
//   setState(() {}); // Refresh balance display
//   ScaffoldMessenger.of(context).showSnackBar(
//     SnackBar(content: Text('Purchase successful!')),
//   );
// };
//
// IAPService.instance.onPurchaseError = (error) {
//   ScaffoldMessenger.of(context).showSnackBar(
//     SnackBar(content: Text('Purchase failed: $error')),
//   );
// };
// ============================================================

*/
