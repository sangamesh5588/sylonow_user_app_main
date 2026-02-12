# Pricing and Location Logic Documentation

## Overview

The app uses a sophisticated location-based pricing system that calculates prices dynamically based on user location and applies various fees and taxes. This document explains how pricing works in both **Nearby Services** and **Service Details** screens.

---

## Location-Based Logic

### How Location Filtering Works

#### 1. **Nearby Services Screen** ([nearby_services_screen.dart](lib/features/home/screens/nearby_services_screen.dart))

**Provider Used**: `popularNearbyServicesProvider`

**Flow**:
```dart
// Step 1: Get user's current location
final userAddress = ref.watch(selectedAddressProvider);
final userLat = userAddress?.latitude ?? 0.0;
final userLon = userAddress?.longitude ?? 0.0;

// Step 2: Fetch services using RPC function
final services = await repository.getPopularNearbyServicesWithLocation(
  userLat: userLat,
  userLon: userLon,
  radiusKm: 25.0,  // Default 25km radius
);
```

**RPC Function Called**: `get_nearby_services_with_price`

**Parameters**:
- `user_lat`: User's latitude (from selected address)
- `user_lon`: User's longitude (from selected address)
- `radius_km`: Search radius in kilometers (default: 25km)
- `service_limit`: Maximum number of services to return

**What the RPC Does**:
1. Calculates distance from user to each service vendor using PostGIS
2. Filters services within the specified radius
3. Calculates location-based fees (if applicable)
4. Adds convenience fee (₹19)
5. Adds transaction fee (3.54%)
6. Applies price rounding (prices end in 49 or 99)
7. Returns services with:
   - `calculated_price`: Total price including all fees
   - `distance_km`: Distance from user
   - `display_original_price`: Original price with fees
   - `display_offer_price`: Discounted price with fees (if discount exists)

---

## Pricing Logic

### 1. Service Listing Prices (Grid View)

**Location**: Nearby Services, Home Screen, Category Pages

**Components**:
- **Base Price**: Service original/offer price from database
- **Convenience Fee**: ₹19 (fixed)
- **Transaction Fee**: 3.54% of base price
- **Location Fee**: Variable based on distance (if applicable)

**Formula**:
```
Total = Base Price + Convenience Fee + (Base Price × 3.54%) + Location Fee
```

**RPC Functions**:
- `calculate_service_listing_price`: For normal service listings
- `calculate_theater_listing_price`: For theater listings

**Code Reference**: [price_calculator.dart:22-44](lib/core/utils/price_calculator.dart#L22-L44)

**Example**:
```dart
// Original price: ₹1000
Base Price:        ₹1000
Convenience Fee:   ₹19
Transaction Fee:   ₹35.40 (3.54% of 1000)
Location Fee:      ₹50 (if 5km away, ₹10/km)
─────────────────────────
Total:             ₹1104.40
Rounded:           ₹1149 (rounded to end in 49)
```

### 2. Service Detail/Checkout Prices

**Location**: Service detail page, booking screens, checkout

**Components**:
- **Base Price**: Service discounted price (after applying offer)
- **Transaction Fee**: 3.54% of discounted price
- **GST**: 18% (only if vendor has GST registration)
- **NO Convenience Fee** (removed at checkout)

**Formula**:
```
Total = Discounted Price + (Discounted Price × 3.54%) + GST (if applicable)
```

**RPC Functions**:
- `calculate_service_detail_price`: For service checkout
- `calculate_theater_detail_price`: For theater checkout

**Code Reference**: [price_calculator.dart:60-89](lib/core/utils/price_calculator.dart#L60-L89)

**Example**:
```dart
// Discounted price: ₹800 (after 20% offer)
// Vendor has GST registration
Discounted Price:  ₹800
Transaction Fee:   ₹28.32 (3.54% of 800)
GST (18%):        ₹144.00
─────────────────────────
Total:            ₹972.32
Rounded:          ₹999 (rounded to end in 99)
```

---

## RPC Functions Used

### 1. **`get_nearby_services_with_price`**

**Purpose**: Fetch services near user with calculated prices

**Called In**:
- [home_repository.dart:230](lib/features/home/repositories/home_repository.dart#L230)

**Parameters**:
```sql
user_lat: DOUBLE PRECISION,
user_lon: DOUBLE PRECISION,
radius_km: DOUBLE PRECISION,
service_limit: INTEGER
```

**Returns**: Array of services with:
- All service fields
- `distance_km`: Distance from user
- `calculated_price`: Price with all fees included
- `display_original_price`: Original price + fees
- `display_offer_price`: Offer price + fees

**Logic Inside RPC**:
```sql
1. Calculate distance using PostGIS: ST_Distance_Sphere(point1, point2)
2. Filter services WHERE distance <= radius_km
3. Calculate location fee based on distance tiers:
   - 0-2 km: No extra fee
   - 2-5 km: ₹10/km
   - 5-10 km: ₹15/km
   - 10-20 km: ₹20/km
   - 20+ km: ₹25/km
4. Add convenience fee (₹19)
5. Add transaction fee (3.54%)
6. Apply rounding
7. Sort by distance (nearest first)
8. LIMIT to service_limit
```

### 2. **`calculate_service_listing_price`**

**Purpose**: Calculate display price for service listings

**Called In**:
- [price_calculator.dart:26](lib/core/utils/price_calculator.dart#L26)

**Parameters**:
```sql
p_service_price: DOUBLE PRECISION
```

**Returns**: Record with:
- `service_price`: Original service price
- `convenience_fee`: ₹19
- `transaction_fee`: 3.54% of service price
- `total_amount`: Sum with rounding

### 3. **`calculate_service_detail_price`**

**Purpose**: Calculate checkout price (no convenience fee)

**Called In**:
- [price_calculator.dart:67](lib/core/utils/price_calculator.dart#L67)
- [home_repository.dart:230](lib/features/home/repositories/home_repository.dart#L230)

**Parameters**:
```sql
p_service_price: DOUBLE PRECISION,
p_vendor_has_gst: BOOLEAN
```

**Returns**: Record with:
- `service_price`: Discounted service price
- `transaction_fee`: 3.54% of price
- `gst_amount`: 18% if vendor has GST (otherwise 0)
- `total_amount`: Sum with rounding

### 4. **`calculate_theater_listing_price`**

**Purpose**: Calculate display price for theater listings

**Called In**:
- [price_calculator.dart:205](lib/core/utils/price_calculator.dart#L205)

**Same logic as `calculate_service_listing_price` but for theaters**

### 5. **`calculate_theater_detail_price`**

**Purpose**: Calculate checkout price for theater bookings

**Called In**:
- [price_calculator.dart:246](lib/core/utils/price_calculator.dart#L246)

**Same logic as `calculate_service_detail_price` but for theaters**

### 6. **`nearby_theaters`**

**Purpose**: Fetch theaters near user location

**Called In**:
- [theater_repository.dart:281](lib/features/theater/repositories/theater_repository.dart#L281)

**Parameters**:
```sql
user_lat: DOUBLE PRECISION,
user_lng: DOUBLE PRECISION,
radius_km: DOUBLE PRECISION
```

**Returns**: Array of theaters within radius

### 7. **`get_services_by_category_and_location`**

**Purpose**: Fetch services by category with location filtering

**Called In**:
- [category_services_providers.dart:59](lib/features/categories/providers/category_services_providers.dart#L59)

**Parameters**:
```sql
p_category_name: TEXT,
p_user_lat: DOUBLE PRECISION,
p_user_lon: DOUBLE PRECISION,
p_radius_km: DOUBLE PRECISION
```

### 8. **`get_services_by_category_decoration_and_location`**

**Purpose**: Fetch services by category + decoration type with location

**Called In**:
- [category_services_providers.dart:199](lib/features/categories/providers/category_services_providers.dart#L199)

**Parameters**:
```sql
p_category_name: TEXT,
p_decoration_type: TEXT,
p_user_lat: DOUBLE PRECISION,
p_user_lon: DOUBLE PRECISION,
p_radius_km: DOUBLE PRECISION
```

---

## Price Display Flow

### Nearby Services Screen Flow

```
1. User opens "Near by" screen
   ↓
2. App reads selected address (lat/lon)
   ↓
3. Calls `popularNearbyServicesProvider`
   ↓
4. Provider calls `getPopularNearbyServicesWithLocation()`
   ↓
5. Repository executes RPC: `get_nearby_services_with_price`
   ↓
6. RPC calculates:
   - Distance from user
   - Location fees
   - Convenience fee
   - Transaction fee
   - Final rounded price
   ↓
7. Returns services with `display_offer_price` or `display_original_price`
   ↓
8. UI displays prices using PriceCalculator.formatPriceAsInt()
   ↓
9. User sees: "₹1149" (all fees included)
```

### Service Detail Flow

```
1. User taps service card
   ↓
2. Navigates to service detail with price from listing
   ↓
3. Detail screen shows breakdown:
   - Service Price: ₹800
   - Transaction Fee: ₹28
   - GST (if applicable): ₹144
   - Total: ₹999
   ↓
4. When user clicks "Book Now"
   ↓
5. Goes to checkout with final price (₹999)
   ↓
6. Payment gateway receives final amount
```

---

## Important Constants

**File**: [price_calculator.dart](lib/core/utils/price_calculator.dart)

```dart
static const double transactionFeeRate = 0.0354;  // 3.54%
static const double gstRate = 0.18;               // 18% GST
static const double convenienceFee = 19.00;       // ₹19 (listings only)
```

---

## Key Differences

| Aspect | Service Listings | Service Detail/Checkout |
|--------|-----------------|-------------------------|
| **Convenience Fee** | ✅ ₹19 included | ❌ Not included |
| **Location Fee** | ✅ Based on distance | ❌ Not included |
| **Transaction Fee** | ✅ 3.54% | ✅ 3.54% |
| **GST** | ❌ Not shown | ✅ 18% (if vendor has GST) |
| **RPC Function** | `calculate_service_listing_price` | `calculate_service_detail_price` |
| **Display Format** | Rounded (ends in 49/99) | Rounded (ends in 49/99) |

---

## Testing Location Logic

### Test Scenarios

**1. Near User (< 2km)**
```
Base Price: ₹1000
Location Fee: ₹0
Convenience: ₹19
Transaction: ₹35.40
Total: ₹1049 (rounded)
```

**2. Medium Distance (5km)**
```
Base Price: ₹1000
Location Fee: ₹50 (₹10/km × 5km)
Convenience: ₹19
Transaction: ₹35.40
Total: ₹1149 (rounded)
```

**3. Far Distance (15km)**
```
Base Price: ₹1000
Location Fee: ₹225 (₹15/km × 15km)
Convenience: ₹19
Transaction: ₹35.40
Total: ₹1349 (rounded)
```

### How to Test

1. **Change User Location**:
   ```dart
   // In app, go to profile → addresses
   // Add/select different addresses at various distances
   ```

2. **Check Nearby Services**:
   ```dart
   // Open "Near by" screen
   // Verify prices change based on selected address
   ```

3. **Verify RPC Calls**:
   ```sql
   -- In Supabase SQL Editor
   SELECT get_nearby_services_with_price(
     28.6139,  -- User lat
     77.2090,  -- User lon
     25.0,     -- Radius
     10        -- Limit
   );
   ```

---

## Common Issues & Solutions

### Issue 1: Prices not updating with location change
**Solution**: Clear provider cache
```dart
ref.invalidate(popularNearbyServicesProvider);
```

### Issue 2: RPC function not found
**Solution**: Ensure RPC functions exist in database
```sql
SELECT routine_name FROM information_schema.routines
WHERE routine_schema = 'public';
```

### Issue 3: Incorrect distance calculation
**Solution**: Verify lat/lon are in correct format (decimal degrees)
- Valid: 28.6139, 77.2090
- Invalid: "28°36'50\"N", "77°12'32\"E"

---

## Summary

✅ **Nearby Services**: Uses RPC `get_nearby_services_with_price` to calculate prices with location fees
✅ **Service Details**: Uses RPC `calculate_service_detail_price` for checkout (no convenience fee)
✅ **Location Filtering**: Based on PostGIS distance calculation within radius
✅ **Price Components**: Base + Location Fee + Convenience Fee + Transaction Fee + GST
✅ **Rounding**: All prices end in 49 or 99 for psychological pricing

All pricing logic is **server-side** in RPC functions to ensure consistency and prevent client-side manipulation.
