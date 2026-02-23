import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shimmer_widget.dart';
import '../../../core/utils/price_calculator.dart';
import '../providers/category_services_providers.dart';
import '../../home/models/service_listing_model.dart';
import '../../address/providers/address_providers.dart';
import '../../address/models/address_model.dart';

class CategoryServicesScreen extends ConsumerStatefulWidget {
  final String categoryName;
  final String? decorationType;
  final String? displayName;

  const CategoryServicesScreen({
    super.key, 
    required this.categoryName,
    this.decorationType,
    this.displayName,
  });

  static const String routeName = '/category';

  @override
  ConsumerState<CategoryServicesScreen> createState() =>
      _CategoryServicesScreenState();
}

class _CategoryServicesScreenState
    extends ConsumerState<CategoryServicesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  final List<String> _filterOptions = [
    'All',
    'Nearby',
    'Within 5 km',
    'Popular',
    'Highest Rated',
    'Price: Low to High',
    'Price: High to Low',
  ];

  Future<void> _onRefresh() async {
    // Invalidate providers to trigger refresh
    if (widget.decorationType != null) {
      ref.invalidate(servicesByCategoryAndDecorationTypeProvider);
    } else {
      ref.invalidate(servicesByCategoryProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🔍 CategoryServicesScreen: Building with categoryName: ${widget.categoryName}, decorationType: ${widget.decorationType}, displayName: ${widget.displayName}');

    // Determine theme colors based on decoration type
    final isInsideDecoration = widget.decorationType == 'inside';
    final primaryColor = isInsideDecoration ? AppTheme.primaryColor : Colors.green;
    final displayTitle = widget.displayName ?? widget.categoryName;

    // Watch selectedAddressProvider directly - this will trigger rebuild when address changes
    final selectedAddress = ref.watch(selectedAddressProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          displayTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontFamily: 'Okra',
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        key: _refreshKey,
        onRefresh: _onRefresh,
        color: primaryColor,
        child: _buildServicesContent(selectedAddress, primaryColor),
      ),
    );
  }

  Widget _buildServicesContent(Address? selectedAddress, Color primaryColor) {
    print('🔍 CategoryServicesScreen: _buildServicesContent called');
    print('🔍 Selected Address: ${selectedAddress?.address}');
    print('🔍 Address Coordinates: lat=${selectedAddress?.latitude}, lon=${selectedAddress?.longitude}');
    print('🔍 Category: ${widget.categoryName}');
    print('🔍 Decoration Type: ${widget.decorationType}');

    // The categoryServicesProvider already watches selectedAddressProvider,
    // so it will automatically refetch when the address changes
    final servicesAsync = ref.watch(
      categoryServicesProvider(widget.categoryName),
    );

    // Log the services data
    servicesAsync.whenData((services) {
      print('🔍 Services loaded: ${services.length} items');
      if (services.isNotEmpty) {
        print('🔍 First service: ${services.first.name}');
        print('🔍 First service prices: original=${services.first.displayOriginalPrice}, offer=${services.first.displayOfferPrice}');
        print('🔍 First service calculated price: ${services.first.calculatedPrice}');
      }
    });

    return _buildServicesView(servicesAsync, primaryColor, isLocationBased: selectedAddress != null);
  }

  Widget _buildServicesView(
    AsyncValue<List<ServiceListingModel>> servicesAsync, 
    Color primaryColor, 
    {bool isLocationBased = false}
  ) {
    print('🔍 CategoryServicesScreen: _buildServicesView called with AsyncValue state: ${servicesAsync.runtimeType}');
    
    return servicesAsync.when(
      loading: () {
        print('🔍 CategoryServicesScreen: AsyncValue is in loading state, showing shimmer');
        return _buildShimmerGrid(primaryColor);
      },
      error: (error, stack) {
        print('🔍 CategoryServicesScreen: AsyncValue error: $error');
        print('🔍 CategoryServicesScreen: Stack trace: $stack');
        return _buildErrorState(primaryColor);
      },
      data: (services) {
        print('🔍 CategoryServicesScreen: AsyncValue data received with ${services.length} services');
        var filtered = _applyFiltering(services);
        print('🔍 CategoryServicesScreen: After filtering: ${filtered.length} services');
        return _buildServicesGrid(filtered, primaryColor, isLocationBased);
      },
    );
  }

  Widget _buildServicesGrid(
    List<ServiceListingModel> services, 
    Color primaryColor, 
    bool isLocationBased
  ) {
    if (services.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(child: _buildEmptyState()),
        ],
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Search Bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search services...',
                prefixIcon: Icon(
                  Icons.search,
                  color: primaryColor,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE1E2E4)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE1E2E4)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryColor),
                ),
              ),
            ),
          ),
        ),
        // Filter Header
        SliverPersistentHeader(
          pinned: true,
          delegate: _FilterHeaderDelegate(
            filterOptions: _filterOptions,
            selectedFilter: _selectedFilter,
            primaryColor: primaryColor,
            onFilterChanged: (filter) {
              setState(() {
                _selectedFilter = filter;
              });
            },
          ),
        ),
        // Services Grid
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.65,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final service = services[index];
                return _buildServiceCard(context, service, isLocationBased);
              },
              childCount: services.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerGrid(Color primaryColor) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.65,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return ShimmerWidgets.categoryServiceCard();
      },
    );
  }

  Widget _buildErrorState(Color primaryColor) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Unable to load services',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Okra',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pull down to refresh',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontFamily: 'Okra',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _refreshKey.currentState?.show(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<ServiceListingModel> _applyFiltering(
    List<ServiceListingModel> services,
  ) {
    var filtered = services;

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }

    // Apply selected filter
    switch (_selectedFilter) {
      case 'Nearby':
        // For now, keep original order (would require location-based sorting)
        break;
      case 'Within 5 km':
        // For now, keep original order (would require location-based filtering)
        break;
      case 'Popular':
        filtered.sort((a, b) => (b.rating ?? 0.0).compareTo(a.rating ?? 0.0));
        break;
      case 'Highest Rated':
        filtered.sort((a, b) => (b.rating ?? 0.0).compareTo(a.rating ?? 0.0));
        break;
      case 'Price: Low to High':
        filtered.sort((a, b) {
          final priceA = a.displayOfferPrice ?? a.displayOriginalPrice ?? double.infinity;
          final priceB = b.displayOfferPrice ?? b.displayOriginalPrice ?? double.infinity;
          return priceA.compareTo(priceB);
        });
        break;
      case 'Price: High to Low':
        filtered.sort((a, b) {
          final priceA = a.displayOfferPrice ?? a.displayOriginalPrice ?? 0.0;
          final priceB = b.displayOfferPrice ?? b.displayOriginalPrice ?? 0.0;
          return priceB.compareTo(priceA);
        });
        break;
      default: // 'All'
        break;
    }

    return filtered;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.category_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No services found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'Okra',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontFamily: 'Okra',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, ServiceListingModel service, bool isLocationBased) {
    // Calculate discount percentage
    int? discountPercentage;
    if (service.displayOriginalPrice != null && service.displayOfferPrice != null) {
      final discount = ((service.displayOriginalPrice! - service.displayOfferPrice!) /
                        service.displayOriginalPrice! * 100);
      discountPercentage = discount.round();
    }

    return GestureDetector(
      onTap: () {
        // Pass the service with all calculated price data to detail screen
        context.push('/service/${service.id}', extra: {
          'service': service,
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service Image with discount badge
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: service.image ?? '',
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primaryColor,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Discount badge
                      if (discountPercentage != null && discountPercentage > 0)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green[600],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.arrow_downward,
                                  color: Colors.white,
                                  size: 10,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '$discountPercentage%',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Okra',
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Wishlist icon
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.favorite_border,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Service Details
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Service Name
                        Text(
                          service.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Okra',
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Service Description
                        if (service.description != null && service.description!.isNotEmpty)
                          Text(
                            service.description!,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'Okra',
                              color: Colors.grey[600],
                            ),
                          ),
                        const Spacer(),
                        // Price section
                        if (service.displayOfferPrice != null) ...[
                          Row(
                            children: [
                              // Original Price (struck through) - RPC already includes all fees
                              if (service.displayOriginalPrice != null)
                                Text(
                                  PriceCalculator.formatPriceAsInt(service.displayOriginalPrice!),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    fontFamily: 'Okra',
                                    color: Colors.grey[600],
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: Colors.grey[600],
                                  ),
                                ),
                              const SizedBox(width: 6),
                              // Offer Price - RPC already includes all fees
                              Text(
                                PriceCalculator.formatPriceAsInt(service.displayOfferPrice!),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Okra',
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ] else if (service.displayOriginalPrice != null) ...[
                          Text(
                            PriceCalculator.formatPriceAsInt(service.displayOriginalPrice!),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Okra',
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Rating in bottom right corner of card
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green[600],
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (service.rating ?? 4.9).toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Okra',
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.star,
                      color: Colors.white,
                      size: 12,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumberWithCommas(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<String> filterOptions;
  final String selectedFilter;
  final Color primaryColor;
  final ValueChanged<String> onFilterChanged;

  _FilterHeaderDelegate({
    required this.filterOptions,
    required this.selectedFilter,
    required this.primaryColor,
    required this.onFilterChanged,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ClipPath(
      clipper: ShapeBorderClipper(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(46)),
      ),
      child: Container(
        color: Colors.grey[50],
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Filter options
              ...filterOptions.map((filter) {
                final isSelected = filter == selectedFilter;
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      filter,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontSize: 13,
                        fontFamily: 'Okra',
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        onFilterChanged(filter);
                      }
                    },
                    backgroundColor: Colors.white,
                    selectedColor: primaryColor,
                    side: BorderSide(
                      color: isSelected
                          ? primaryColor
                          : Colors.grey[300]!,
                    ),
                    showCheckmark: false,
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 56;

  @override
  double get minExtent => 56;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return oldDelegate != this;
  }
}
