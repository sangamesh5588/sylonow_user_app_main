import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_model.dart';

class OrderRepository {
  final SupabaseClient _supabase;

  OrderRepository(this._supabase);

  /// Create a new order in the database
  Future<OrderModel> createOrder({
    required String userId,
    required String vendorId,
    required String customerName,
    required String serviceListingId,
    required String serviceTitle,
    required DateTime bookingDate,
    required double totalAmount,
    required double advanceAmount,
    required double remainingAmount,
    String? customerPhone,
    String? customerEmail,
    String? serviceDescription,
    String? bookingTime,
    String? specialRequirements,
    String? addressId,
    String? placeImageUrl,
    String? bannerImage,
    int? age,
    String? occasion,
    List<Map<String, dynamic>>? addOns,
    String? customisationInput,
  }) async {
    print('🏪 [REPOSITORY] OrderRepository.createOrder() called');
    try {
      print('🧹 [REPOSITORY] Validating and cleaning UUID inputs');
      // Validate and clean UUID inputs
      final cleanUserId = userId.trim().isEmpty ? null : userId;
      final cleanVendorId = vendorId.trim().isEmpty || vendorId == 'unknown-vendor' ? null : vendorId;
      final cleanServiceListingId = serviceListingId.trim().isEmpty ? null : serviceListingId;
      
      print('🧹 [REPOSITORY] Cleaned values:');
      print('🧹 [REPOSITORY]   cleanUserId: $cleanUserId');
      print('🧹 [REPOSITORY]   cleanVendorId: $cleanVendorId');
      print('🧹 [REPOSITORY]   cleanServiceListingId: $cleanServiceListingId');

      print('📋 [REPOSITORY] Building order data object');
      final orderData = <String, dynamic>{
        'customer_name': customerName,
        'service_title': serviceTitle,
        'booking_date': bookingDate.toIso8601String(),
        'total_amount': totalAmount,
        'advance_amount': advanceAmount,
        'remaining_amount': remainingAmount,
        'status': 'pending',
        'payment_status': 'pending',
      };

      print('➕ [REPOSITORY] Adding optional fields');
      // Add optional fields only if they have valid values
      if (cleanUserId != null) {
        orderData['user_id'] = cleanUserId;
        print('➕ [REPOSITORY] Added user_id: $cleanUserId');
      }
      if (cleanVendorId != null) {
        orderData['vendor_id'] = cleanVendorId;
        print('➕ [REPOSITORY] Added vendor_id: $cleanVendorId');
      }
      if (cleanServiceListingId != null) {
        orderData['service_listing_id'] = cleanServiceListingId;
        print('➕ [REPOSITORY] Added service_listing_id: $cleanServiceListingId');
      }
      if (customerPhone?.isNotEmpty == true) {
        orderData['customer_phone'] = customerPhone;
        print('➕ [REPOSITORY] Added customer_phone: $customerPhone');
      }
      if (customerEmail?.isNotEmpty == true) {
        orderData['customer_email'] = customerEmail;
        print('➕ [REPOSITORY] Added customer_email: $customerEmail');
      }
      if (serviceDescription?.isNotEmpty == true) {
        orderData['service_description'] = serviceDescription;
        print('➕ [REPOSITORY] Added service_description: $serviceDescription');
      }
      if (bookingTime?.isNotEmpty == true) {
        orderData['booking_time'] = bookingTime;
        print('➕ [REPOSITORY] Added booking_time: $bookingTime');
      }
      if (specialRequirements?.isNotEmpty == true) {
        orderData['special_requirements'] = specialRequirements;
        print('➕ [REPOSITORY] Added special_requirements: $specialRequirements');
      }
      if (addressId?.isNotEmpty == true) {
        orderData['address_id'] = addressId;
        print('➕ [REPOSITORY] Added address_id: $addressId');
      }
      if (placeImageUrl?.isNotEmpty == true) {
        orderData['place_image_url'] = placeImageUrl;
        print('➕ [REPOSITORY] Added place_image_url: $placeImageUrl');
      }
      if (bannerImage?.isNotEmpty == true) {
        orderData['banner_image'] = bannerImage;
        print('➕ [REPOSITORY] Added banner_image: $bannerImage');
      }
      if (age != null && age > 0) {
        orderData['age'] = age;
        print('➕ [REPOSITORY] Added age: $age');
      }
      if (occasion?.isNotEmpty == true) {
        orderData['occasion'] = occasion;
        print('➕ [REPOSITORY] Added occasion: $occasion');
      }
      if (customisationInput?.isNotEmpty == true) {
        orderData['customisation_input'] = customisationInput;
        print('➕ [REPOSITORY] Added customisation_input: $customisationInput');
      }

      print('📤 [REPOSITORY] Final order data to be inserted:');
      print('📤 [REPOSITORY] ${orderData.toString()}');
      
      print('🚀 [REPOSITORY] Executing Supabase insert query');
      final response = await _supabase
          .from('orders')
          .insert(orderData)
          .select()
          .single();

      print('✅ [REPOSITORY] Supabase insert successful');
      print('✅ [REPOSITORY] Response: $response');

      print('🔄 [REPOSITORY] Converting response to OrderModel');
      final order = OrderModel.fromJson(response);
      print('✅ [REPOSITORY] OrderModel created successfully: ${order.id}');

      // Insert add-ons into order_add_ons junction table
      if (addOns != null && addOns.isNotEmpty) {
        final addOnRows = addOns.map((a) {
          final row = <String, dynamic>{
            'order_id': order.id,
            'add_on_id': a['add_on_id'],
            'quantity': a['quantity'] ?? 1,
            'price_at_booking': a['price_at_booking'] ?? 0,
          };
          if (a['customisation_input'] != null) {
            row['customisation_input'] = a['customisation_input'];
          }
          return row;
        }).toList();
        await _supabase.from('order_add_ons').insert(addOnRows);
        print('✅ [REPOSITORY] Inserted ${addOnRows.length} add-on(s) into order_add_ons');
      }

      return order;
    } catch (e) {
      print('❌ [REPOSITORY] Error in createOrder');
      print('❌ [REPOSITORY] Error type: ${e.runtimeType}');
      print('❌ [REPOSITORY] Error message: $e');
      throw Exception('Failed to create order: $e');
    }
  }

  /// Update order payment status
  Future<OrderModel> updateOrderPayment({
    required String orderId,
    String? paymentStatus,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      
      if (paymentStatus != null) {
        updateData['payment_status'] = paymentStatus;
      }
      
      updateData['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('orders')
          .update(updateData)
          .eq('id', orderId)
          .select()
          .single();

      return OrderModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update order payment: $e');
    }
  }

  /// Update order status
  Future<OrderModel> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    try {
      final response = await _supabase
          .from('orders')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId)
          .select()
          .single();

      return OrderModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
  }

  /// Get order by ID
  Future<OrderModel?> getOrderById(String orderId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select()
          .eq('id', orderId)
          .maybeSingle();

      if (response == null) return null;
      return OrderModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get order: $e');
    }
  }

  /// Get user orders
  Future<List<OrderModel>> getUserOrders(String userId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('''
            *,
            service_listings(cover_photo),
            addresses(address_for, address, area, nearby, name, floor, city, state),
            order_add_ons(add_on_id, quantity, price_at_booking, customisation_input, service_add_ons(id, name, discount_price, original_price, images))
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return response.map<OrderModel>((json) {
        final Map<String, dynamic> orderJson = Map<String, dynamic>.from(json);

        final serviceListings = json['service_listings'];
        if (serviceListings is Map<String, dynamic>) {
          if (serviceListings['cover_photo'] != null) {
            orderJson['service_image_url'] = serviceListings['cover_photo'];
          }
        } else if (serviceListings is List && serviceListings.isNotEmpty) {
          final first = serviceListings.first;
          if (first is Map<String, dynamic> && first['cover_photo'] != null) {
            orderJson['service_image_url'] = first['cover_photo'];
          }
        }

        final addresses = json['addresses'];
        if (addresses != null) {
          final addressData = addresses is Map<String, dynamic>
              ? addresses
              : (addresses is List && addresses.isNotEmpty && addresses.first is Map<String, dynamic>)
                  ? addresses.first as Map<String, dynamic>
                  : <String, dynamic>{};
          orderJson['address_full'] = addressData['address'];
          orderJson['address_area'] = addressData['area'];
          orderJson['address_nearby'] = addressData['nearby'];
          orderJson['address_name'] = addressData['name'];
          orderJson['address_floor'] = addressData['floor'];
          orderJson['address_for'] = addressData['address_for'];
          orderJson['address_city'] = addressData['city'];
          orderJson['address_state'] = addressData['state'];
        }

        // Flatten order_add_ons for the model
        if (json['order_add_ons'] is List) {
          orderJson['order_add_ons'] = (json['order_add_ons'] as List).map((item) {
            final itemMap = item is Map<String, dynamic> ? item : <String, dynamic>{};
            final serviceAddOnData = itemMap['service_add_ons'];
            final addOn = serviceAddOnData is Map<String, dynamic>
                ? serviceAddOnData
                : (serviceAddOnData is List &&
                        serviceAddOnData.isNotEmpty &&
                        serviceAddOnData.first is Map<String, dynamic>)
                    ? serviceAddOnData.first as Map<String, dynamic>
                    : <String, dynamic>{};
            return {
              'add_on_id': itemMap['add_on_id'],
              'quantity': itemMap['quantity'],
              'price_at_booking': itemMap['price_at_booking'],
              'customisation_input': itemMap['customisation_input'],
              'name': addOn['name'],
              'discount_price': addOn['discount_price'],
              'original_price': addOn['original_price'],
              'images': addOn['images'],
            };
          }).toList();
        }

        orderJson.remove('service_listings');
        orderJson.remove('addresses');

        return OrderModel.fromJson(orderJson);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get user orders: $e');
    }
  }

  /// Get vendor orders
  Future<List<OrderModel>> getVendorOrders(String vendorId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select()
          .eq('vendor_id', vendorId)
          .order('created_at', ascending: false);

      return response.map<OrderModel>((json) => OrderModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get vendor orders: $e');
    }
  }

  /// Update order place image URL
  Future<OrderModel> updateOrderPlaceImage({
    required String orderId,
    required String placeImageUrl,
  }) async {
    try {
      final response = await _supabase
          .from('orders')
          .update({
            'place_image_url': placeImageUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId)
          .select()
          .single();

      return OrderModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update order place image: $e');
    }
  }
}
