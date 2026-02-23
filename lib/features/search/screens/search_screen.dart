import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:sylonow_user/features/search/providers/search_providers.dart';
import 'package:sylonow_user/features/home/models/service_listing_model.dart';
import 'package:sylonow_user/core/utils/image_cache_manager.dart';
import 'package:sylonow_user/core/utils/price_calculator.dart';

class SearchScreen extends ConsumerStatefulWidget {
  static const String routeName = '/search';
  
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;
  String _currentQuery = '';
  bool _showClearButton = false;

  static const List<String> _searchSuggestions = [
    'Birthaday Decoration',
    'Theme Parties',
    'Corporate Events',
    'Baby shower',
    'Anniversary Decoration',
    'Couple Surprise',
    'Indoor Decoration',
    'Sangeet Decoration',
    'Party Decoration',
    'Ballon deco',
    'Private Theater',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    
    setState(() {
      _showClearButton = query.isNotEmpty;
    });
    
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isNotEmpty && query.trim() != _currentQuery) {
        setState(() {
          _currentQuery = query.trim();
        });
        ref.read(searchResultsProvider(query.trim()));
      }
    });
  }

  void _performSearch(String query) {
    if (query.trim().isNotEmpty) {
      _searchController.text = query;
      setState(() {
        _currentQuery = query.trim();
      });
      _focusNode.unfocus();
      ref.read(searchResultsProvider(query.trim()));
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _debounceTimer?.cancel();
    setState(() {
      _currentQuery = '';
      _showClearButton = false;
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = _currentQuery.isNotEmpty 
        ? ref.watch(searchResultsProvider(_currentQuery))
        : const AsyncValue<List<ServiceListingModel>>.data([]);
    
    final recentSearches = ref.watch(recentSearchesProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildSearchAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _currentQuery.isEmpty
                ? _buildSearchSuggestions(recentSearches)
                : _buildSearchResults(searchResults),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildSearchAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      scrolledUnderElevation: 0,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 12,
      title: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            // Back button integrated in search bar
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 22),
              onPressed: () => context.pop(),
              splashRadius: 20,
            ),
            
            // Search input
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                onChanged: _onSearchChanged,
                onSubmitted: _performSearch,
                decoration: InputDecoration(
                  filled: false,
                  hintText: 'Search services...',
                  hintStyle: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontFamily: 'Okra',
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'Okra',
                  color: Colors.black87,
                ),
              ),
            ),
            
            // Clear button or search icon
            if (_showClearButton)
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                onPressed: _clearSearch,
                splashRadius: 20,
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.search, color: const Color.fromARGB(255, 0, 0, 0), size: 22),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSuggestions(List<String> recentSearches) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Searches',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Okra',
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(recentSearchesProvider.notifier).clearAll();
                  },
                  child: const Text(
                    'Clear All',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontFamily: 'Okra',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...recentSearches.map((search) => _buildSearchItem(
              search,
              Icons.history,
              onTap: () => _performSearch(search),
              onDelete: () => ref.read(recentSearchesProvider.notifier).remove(search),
            )),
            const SizedBox(height: 24),
          ],
          
          const Text(
            'Popular Searches',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Okra',
            ),
          ),
          const SizedBox(height: 8),
          ..._searchSuggestions.map((suggestion) => _buildSearchItem(
            suggestion,
            Icons.trending_up,
            onTap: () => _performSearch(suggestion),
          )),
        ],
      ),
    );
  }

  Widget _buildSearchItem(
    String text,
    IconData icon, {
    required VoidCallback onTap,
    VoidCallback? onDelete,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey, size: 20),
      title: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontFamily: 'Okra',
        ),
      ),
      trailing: onDelete != null
          ? IconButton(
              icon: const Icon(Icons.close, color: Colors.grey, size: 18),
              onPressed: onDelete,
            )
          : const Icon(Icons.north_west, color: Colors.grey, size: 16),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
    );
  }

  Widget _buildSearchResults(AsyncValue<List<ServiceListingModel>> searchResults) {
    return searchResults.when(
      loading: () => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.pink),
            SizedBox(height: 16),
            Text(
              'Searching...',
              style: TextStyle(
                color: Colors.grey,
                fontFamily: 'Okra',
              ),
            ),
          ],
        ),
      ),
      error: (error, stack) => _buildErrorState(error),
      data: (services) {
        if (services.isEmpty) {
          return _buildEmptyState();
        }
        
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(searchResultsProvider(_currentQuery));
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: services.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final service = services[index];
              return _buildServiceCard(service);
            },
          ),
        );
      },
    );
  }

  Widget _buildServiceCard(ServiceListingModel service) {
    return Container(
      height: 125,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD6D8DC), width: 1.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            ref.read(recentSearchesProvider.notifier).add(_currentQuery);
            context.push('/service/${service.id}', extra: {
              'serviceName': service.name,
              'price': service.displayOfferPrice != null
                  ? '₹${service.displayOfferPrice!.round()}'
                  : service.displayOriginalPrice != null
                      ? '₹${service.displayOriginalPrice!.round()}'
                      : null,
              'rating': (service.rating ?? 4.9).toStringAsFixed(1),
              'reviewCount': service.reviewsCount ?? 0,
            });
          },
          child: Row(
            children: [
              // Image section - Fixed size container
              Container(
                width: 120,
                height: 125,
                padding: const EdgeInsets.all(2),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  child: (service.image?.isNotEmpty ?? false)
                      ? AppImageCacheManager.buildOptimizedNetworkImage(
                          imageUrl: service.image!,
                          width: 120,
                          height: 125,
                          fit: BoxFit.cover,
                        )
                      : Container(
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
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Okra',
                          color: Color(0xFF333333),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        service.description?.isNotEmpty == true
                            ? service.description!
                            : 'Beautiful decoration service',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Okra',
                          color: Color(0xFF666666),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (service.distanceKm != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 10,
                              color: Color(0xFF999999),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${service.distanceKm!.toStringAsFixed(1)} km away',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                                fontFamily: 'Okra',
                                color: Color(0xFF999999),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (service.displayOfferPrice != null) ...[
                            if (service.displayOriginalPrice != null &&
                                service.displayOriginalPrice! >
                                    service.displayOfferPrice!) ...[
                              Text(
                                PriceCalculator.formatPriceAsInt(
                                  service.displayOriginalPrice!,
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Okra',
                                  color: Color(0xFF999999),
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: Color(0xFF999999),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              PriceCalculator.formatPriceAsInt(
                                service.displayOfferPrice!,
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Okra',
                                color: Color(0xFF333333),
                              ),
                            ),
                          ] else if (service.displayOriginalPrice != null) ...[
                            Text(
                              PriceCalculator.formatPriceAsInt(
                                service.displayOriginalPrice!,
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Okra',
                                color: Color(0xFF333333),
                              ),
                            ),
                          ] else ...[
                            const Text(
                              'Price on request',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Okra',
                                color: Color(0xFF999999),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Icon(
                            Icons.star,
                            color: Color(0xFFFFD700),
                            size: 14,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            (service.rating ?? 4.9).toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Okra',
                              color: Color(0xFF333333),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No results found for "$_currentQuery"',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Okra',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching with different keywords\nor browse our categories',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontFamily: 'Okra',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _clearSearch,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 255, 72, 16),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              'Try New Search',
              style: TextStyle(fontFamily: 'Okra'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
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
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              ref.invalidate(searchResultsProvider(_currentQuery));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(fontFamily: 'Okra'),
            ),
          ),
        ],
      ),
    );
  }
}
