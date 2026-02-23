import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sylonow_user/core/theme/app_theme.dart';
import 'package:sylonow_user/features/outside/models/addon_model.dart';
import 'package:sylonow_user/features/outside/models/theater_screen_model.dart';
import 'package:sylonow_user/features/outside/providers/theater_screen_detail_providers.dart';
import 'package:sylonow_user/features/cakes/providers/cake_providers.dart';
import 'package:sylonow_user/features/cakes/models/cake_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OutsideAddonsScreen extends ConsumerStatefulWidget {
  static const String routeName = '/outside/addons';

  final String screenId;
  final String selectedDate;
  final Map<String, dynamic> selectionData;

  const OutsideAddonsScreen({
    super.key,
    required this.screenId,
    required this.selectedDate,
    required this.selectionData,
  });

  @override
  ConsumerState<OutsideAddonsScreen> createState() =>
      _OutsideAddonsScreenState();
}

class _OutsideAddonsScreenState extends ConsumerState<OutsideAddonsScreen> {
  final Map<String, int> selectedCakes = {};

  /// Markup percentage for cakes (3.54%)
  static const double _cakeMarkupPercent = 3.54;

  /// Calculate price with markup
  double _calculatePriceWithMarkup(double basePrice) {
    return basePrice * (1 + _cakeMarkupPercent / 100);
  }

  /// Extracts the theaterId from selectionData
  String get _theaterId {
    final screenData = widget.selectionData['screen'];
    if (screenData is TheaterScreen) {
      return screenData.theaterId;
    } else if (screenData is Map<String, dynamic>) {
      return screenData['theater_id'] as String? ??
          screenData['theaterId'] as String? ??
          '';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    // Debug: Basic screen load indicator
    print('🔍 OUTSIDE ADDONS SCREEN LOADED - theaterId: $_theaterId');

    // Debug: Print theaterId and selectionData
    print('DEBUG: theaterId = $_theaterId');
    print('DEBUG: selectionData keys = ${widget.selectionData.keys.toList()}');

    // Fetch cakes for this theater
    final cakesAsync = ref.watch(
      theaterCakesProvider(TheaterCakeParams(theaterId: _theaterId)),
    );

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add-ons & Extras',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Okra',
              ),
            ),
            if (selectedCakes.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_getTotalSelectedCount()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(),

          // Cakes List
          Expanded(
            child: cakesAsync.when(
              data: (cakes) {
                // Debug: Print cakes data
                print('DEBUG: All cakes = $cakes');
                print('DEBUG: Cakes count = ${cakes.length}');

                // Filter to show only available cakes
                final availableCakes = cakes
                    .where((cake) => cake.isAvailable)
                    .toList();

                print('DEBUG: Available cakes = $availableCakes');
                print(
                  'DEBUG: Available cakes count = ${availableCakes.length}',
                );

                if (availableCakes.isEmpty) {
                  return Container(
                    color: Colors.white,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cake, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No cakes available',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              fontFamily: 'Okra',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: availableCakes.length,
                  itemBuilder: (context, index) {
                    final cake = availableCakes[index];
                    return _buildCakeCard(cake);
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              ),
              error: (error, stackTrace) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load cakes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Okra',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please check your connection and try again',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontFamily: 'Okra',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Continue Button
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Skip Button
                Expanded(
                  child: OutlinedButton(
                    onPressed: _continueToExtraSpecial,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                        fontFamily: 'Okra',
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Continue Button
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _continueToExtraSpecial,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      selectedCakes.isEmpty
                          ? 'Continue'
                          : 'Continue (₹${_getTotalPrice().round()})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Okra',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCakeCard(CakeModel cake) {
    final quantity = selectedCakes[cake.id] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: quantity > 0 ? AppTheme.primaryColor : Colors.grey[200]!,
          width: quantity > 0 ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Cake Image
            Container(
              width: 80,
              height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: cake.imageUrl != null && cake.imageUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: cake.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Center(
                        child: Icon(Icons.cake, size: 32, color: Colors.grey[400]),
                      ),
                      errorWidget: (context, url, error) =>
                          Icon(Icons.cake, size: 32, color: Colors.grey[400]),
                    ),
                  )
                : Icon(Icons.cake, size: 32, color: Colors.grey[400]),
          ),
          const SizedBox(width: 16),

          // Cake Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  cake.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontFamily: 'Okra',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (cake.flavor?.isNotEmpty == true) ...{
                  const SizedBox(height: 4),
                  Text(
                    cake.flavor!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontFamily: 'Okra',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                },
                const SizedBox(height: 6),
                Text(
                  '₹${_calculatePriceWithMarkup(cake.price).round()}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                    fontFamily: 'Okra',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Quantity Controls
          if (quantity == 0)
            GestureDetector(
              onTap: () => _updateCakeQuantity(cake.id, 1),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _updateCakeQuantity(cake.id, quantity - 1),
                    child: Container(
                      width: 32,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(10),
                          bottomLeft: Radius.circular(10),
                        ),
                      ),
                      child: const Icon(
                        Icons.remove,
                        color: AppTheme.primaryColor,
                        size: 18,
                      ),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                    ),
                    child: Text(
                      quantity.toString(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Okra',
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _updateCakeQuantity(cake.id, quantity + 1),
                    child: Container(
                      width: 32,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: AppTheme.primaryColor,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateCakeQuantity(String cakeId, int newQuantity) {
    setState(() {
      if (newQuantity <= 0) {
        selectedCakes.remove(cakeId);
      } else {
        selectedCakes[cakeId] = newQuantity;
      }
    });
  }

  int _getTotalSelectedCount() {
    return selectedCakes.values.fold(0, (sum, quantity) => sum + quantity);
  }

  double _getTotalPrice() {
    double total = 0;

    // Calculate cake prices with markup
    final cakesAsync = ref.read(
      theaterCakesProvider(TheaterCakeParams(theaterId: _theaterId)),
    );

    cakesAsync.whenData((cakes) {
      for (final entry in selectedCakes.entries) {
        final cakeId = entry.key;
        final quantity = entry.value;

        final cake = cakes.firstWhere(
          (c) => c.id == cakeId,
          orElse: () =>
              const CakeModel(id: '', theaterId: '', name: '', price: 0),
        );
        if (cake.id.isNotEmpty) {
          // Apply 3.54% markup to cake price
          total += _calculatePriceWithMarkup(cake.price) * quantity;
        }
      }
    });

    return total;
  }

  void _continueToExtraSpecial() {
    final cakesValue =
        ref
            .read(
              theaterCakesProvider(TheaterCakeParams(theaterId: _theaterId)),
            )
            .value ??
        [];

    final List<Map<String, dynamic>> selectedCakesList = [];

    // Convert selected cakes to the expected format for navigation
    for (final entry in selectedCakes.entries) {
      final cakeId = entry.key;
      final quantity = entry.value;

      final cake = cakesValue.firstWhere(
        (c) => c.id == cakeId,
        orElse: () =>
            const CakeModel(id: '', theaterId: '', name: '', price: 0),
      );
      if (cake.id.isNotEmpty) {
        selectedCakesList.add({
          'id': cake.id,
          'quantity': quantity,
          'name': cake.name,
          'price': cake.price
        });
      }
    }

    // Calculate total cake price with 3.54% markup
    double totalCakePrice = selectedCakesList.fold(0.0, (sum, cakeItem) {
      final cakeId = cakeItem['id'] as String?;
      final quantity = cakeItem['quantity'] as int;
      if (cakeId == null || cakeId.isEmpty) {
        return sum;
      }
      final cake = cakesValue.firstWhere(
        (c) => c.id == cakeId,
        orElse: () =>
            const CakeModel(id: '', theaterId: '', name: '', price: 0),
      );
      return sum + (_calculatePriceWithMarkup(cake.price) * quantity);
    });

    // Navigate to extra special screen
    context.push(
      '/outside/${widget.screenId}/extra-special',
      extra: {
        ...widget.selectionData,
        'selectedCakes': selectedCakesList,
        'totalCakePrice': totalCakePrice,
        'selectedDate': widget.selectedDate,
        'screenId': widget.screenId,
      },
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          _buildProgressDot(true, 'Add-ons'),
          _buildProgressLine(true),
          _buildProgressDot(false, 'Special\nServices'),
          _buildProgressLine(false),
          _buildProgressDot(false, 'Extra Special'),
          _buildProgressLine(false),
          _buildProgressDot(false, 'Checkout'),
        ],
      ),
    );
  }

  Widget _buildProgressDot(bool isActive, String label) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isActive ? AppTheme.primaryColor : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: isActive
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              fontFamily: 'Okra',
              color: isActive ? AppTheme.primaryColor : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressLine(bool isActive) {
    return Container(
      height: 2,
      width: 20,
      color: isActive ? AppTheme.primaryColor : Colors.grey[300],
      margin: const EdgeInsets.only(bottom: 24),
    );
  }
}
