# Pricing Fluctuation and Discount Calculation Issues - Analysis & Fix

## Problem Summary

You're experiencing price fluctuations and incorrect discount calculations when:
1. Viewing service in featured section (₹4699)
2. Going to service detail page (price may change)
3. Going to checkout page (₹4900 shown, but then ₹3149 advance)

## Root Causes Identified

### 1. **DOUBLE FEE APPLICATION** ⚠️ CRITICAL

**Location:** `checkout_screen.dart` line 2939

```dart
final servicePriceWithFeesRaw = servicePrice + 19.00 + (servicePrice * 0.0354);
```

**Problem:**
- `servicePrice` comes from `_getServicePrice()` (line 3612)
- Which uses `widget.service.displayOfferPrice`
- `displayOfferPrice` returns `calculatedPrice` if available (line 89 in service_listing_model.dart)
- `calculatedPrice` is from RPC which **ALREADY INCLUDES** ₹19 convenience fee + 3.54% transaction fee
- Then checkout adds ANOTHER ₹19 + 3.54% on top = **DOUBLE CHARGING**

**Evidence:**
- Featured card shows ₹4699 (from `displayOfferPrice` with fees included)
- Checkout calculates: ₹4699 + ₹19 + (₹4699 × 0.0354) = ₹4884.35 → rounded to ₹4900
- This is why ₹4699 becomes ₹4900!

### 2. **INCORRECT DISCOUNT CALCULATION**

**Location:** `service_listing_model.dart` lines 173-178

```dart
int? discountPercentage;
if (service.displayOriginalPrice != null && service.displayOfferPrice != null) {
  final discount = ((service.displayOriginalPrice! - service.displayOfferPrice!) /
                    service.displayOriginalPrice! * 100);
  discountPercentage = discount.round();
}
```

**Problem:**
- `displayOriginalPrice` includes ALL fees (distance + ₹19 + 3.54%)
- `displayOfferPrice` includes ALL fees (distance + ₹19 + 3.54%)
- Discount % is calculated on prices WITH fees
- But original discount was on BASE prices WITHOUT fees
- This causes incorrect discount % display

**Example:**
- Original price (base): ₹8299
- Offer price (base): ₹4699
- Actual discount: (8299 - 4699) / 8299 = 43.4%

- Original price (with fees): ₹8299 + distance + ₹19 + 3.54% ≈ ₹8642
- Offer price (with fees): ₹4699 + distance + ₹19 + 3.54% ≈ ₹4900
- Calculated discount: (8642 - 4900) / 8642 = 43.3%

The discount % appears similar but the ABSOLUTE savings are wrong because fees shouldn't be part of discount calculation.

### 3. **PRICE RECALCULATION ON LOCATION CHANGE**

**Location:** `service_listing_model.dart` lines 96-110

```dart
if (calculatedPrice != null && distanceKm != null && originalPrice != null && offerPrice != null) {
  final extraDistance = math.max(0.0, distanceKm! - (freeServiceKm ?? 0.0));
  final extraCharges = extraDistance * (extraChargesPerKm ?? 0.0);
  final baseWithDistance = originalPrice! + extraCharges;
  const convenienceFee = 19.00;
  const transactionFeeRate = 0.0354;
  final transactionFee = baseWithDistance * transactionFeeRate;
  final totalOriginalPrice = baseWithDistance + convenienceFee + transactionFee;
  return PriceRounding.applyFinalRounding(totalOriginalPrice);
}
```

**Problem:**
- Every time user location changes, distance recalculates
- This triggers new `displayOriginalPrice` calculation
- Causes price to fluctuate based on distance

## Solutions

### Fix 1: Remove Double Fee in Checkout ✅

**File:** `lib/features/booking/screens/checkout_screen.dart`
**Line:** 2939

**Change FROM:**
```dart
final servicePriceWithFeesRaw = servicePrice + 19.00 + (servicePrice * 0.0354);
```

**Change TO:**
```dart
// Service price already includes all fees from displayOfferPrice/calculatedPrice
// Do NOT add fees again
final servicePriceWithFeesRaw = servicePrice;
```

### Fix 2: Calculate Discount on Base Prices ✅

**File:** `lib/features/home/widgets/featured/featured_section.dart`
**Lines:** 172-178

**Change FROM:**
```dart
int? discountPercentage;
if (service.displayOriginalPrice != null && service.displayOfferPrice != null) {
  final discount = ((service.displayOriginalPrice! - service.displayOfferPrice!) /
                    service.displayOriginalPrice! * 100);
  discountPercentage = discount.round();
}
```

**Change TO:**
```dart
int? discountPercentage;
// Calculate discount on BASE prices (without fees) for accurate percentage
if (service.originalPrice != null && service.offerPrice != null) {
  final discount = ((service.originalPrice! - service.offerPrice!) /
                    service.originalPrice! * 100);
  discountPercentage = discount.round();
}
```

### Fix 3: Add Price Consistency Check

**File:** `lib/features/booking/screens/checkout_screen.dart`
**Add after line 2935:**

```dart
Widget _buildBillDetails() {
  final servicePrice = _getServicePrice();
  final addOnsTotal = _calculateSelectedAddOnsTotal();

  // DEBUG: Log to verify prices
  debugPrint('🔍 Service Price Source:');
  debugPrint('   - displayOfferPrice: ${widget.service.displayOfferPrice}');
  debugPrint('   - calculatedPrice: ${widget.service.calculatedPrice}');
  debugPrint('   - offerPrice: ${widget.service.offerPrice}');
  debugPrint('   - Final servicePrice used: $servicePrice');

  // Service price already includes all fees if from calculatedPrice/displayOfferPrice
  final servicePriceWithFeesRaw = servicePrice;
  // ... rest of code
}
```

## Expected Results After Fix

### Before Fix:
- Featured card: ₹4699 (with fees included)
- Checkout: ₹4900 (fees added again) ❌
- Item Total: ₹4900
- Convenience Fee: ₹0 (hidden because already doubled)
- Total: ₹4900

### After Fix:
- Featured card: ₹4699 (with fees included)
- Checkout: ₹4699 (no double fees) ✅
- Item Total: ₹4699
- Convenience Fee: ₹0 (already included)
- Total: ₹4699

### Discount Display:
- Before: Calculated on prices with fees (slightly inaccurate %)
- After: Calculated on base prices (accurate % like "Flat 43% off")

## Files to Modify

1. **lib/features/booking/screens/checkout_screen.dart**
   - Line 2939: Remove double fee addition
   - Add debug logging

2. **lib/features/home/widgets/featured/featured_section.dart**
   - Lines 172-178: Use base prices for discount calculation

3. **lib/features/services/screens/service_detail_screen.dart** (check same issue)
   - Search for similar discount calculation logic

4. **lib/features/discounts/screens/discounted_services_screen.dart** (check same issue)
   - Search for similar discount calculation logic

## Testing Steps

1. Clear app cache/data
2. Open featured section, note price (e.g., ₹4699)
3. Tap service, verify detail page shows same ₹4699
4. Tap "Book Now", verify checkout shows ₹4699 (not ₹4900)
5. Verify discount % matches original offer (e.g., "Flat 43%")
6. Change address/location, verify price updates consistently
7. Add add-ons, verify total calculation is correct

## Additional Notes

- The RPC function `calculate_service_listing_price` already includes all fees
- The checkout should TRUST this price and not recalculate
- All discount displays should use BASE prices (without fees)
- Consider adding a flag `hasPrecalculatedFees` to service model to make this explicit
