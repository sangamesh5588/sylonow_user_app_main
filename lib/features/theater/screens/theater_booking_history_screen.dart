import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../models/theater_booking_model.dart';
import '../providers/theater_providers.dart';

class TheaterBookingHistoryScreen extends ConsumerStatefulWidget {
  const TheaterBookingHistoryScreen({super.key});

  static const String routeName = '/profile/theater-bookings';

  @override
  ConsumerState<TheaterBookingHistoryScreen> createState() => _TheaterBookingHistoryScreenState();
}

class _TheaterBookingHistoryScreenState extends ConsumerState<TheaterBookingHistoryScreen> {
  String _selectedFilter = 'all';
  final List<String> _filters = ['all', 'confirmed', 'completed', 'cancelled'];

  @override
  Widget build(BuildContext context) {
    final bookingsAsyncValue = ref.watch(userTheaterBookingsProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Theater Bookings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: 'Okra',
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 24),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: bookingsAsyncValue.when(
              data: (bookings) {
                final filteredBookings = _filterBookings(bookings);
                
                if (filteredBookings.isEmpty) {
                  return _buildEmptyState();
                }
                
                return _buildBookingsList(filteredBookings);
              },
              loading: () => _buildLoadingState(),
              error: (error, stack) => _buildErrorState(error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilterChip(
                label: Text(
                  _getFilterDisplayName(filter),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontFamily: 'Okra',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                },
                backgroundColor: Colors.white,
                selectedColor: AppTheme.primaryColor,
                checkmarkColor: Colors.white,
                side: BorderSide(
                  color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getFilterDisplayName(String filter) {
    switch (filter) {
      case 'all':
        return 'All';
      case 'confirmed':
        return 'Confirmed';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return filter;
    }
  }

  List<TheaterBookingModel> _filterBookings(List<TheaterBookingModel> bookings) {
    if (_selectedFilter == 'all') return bookings;
    return bookings.where((booking) => booking.bookingStatus == _selectedFilter).toList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.movie_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No theater bookings found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'Okra',
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You haven\'t made any theater bookings yet.',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Okra',
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              try {
                context.push('/outside-theaters');
              } catch (e) {
                // Fallback navigation if push fails
                context.go('/outside-theaters');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Book a Theater',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Okra',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: AppTheme.primaryColor,
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
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading bookings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'Okra',
              color: Colors.red[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Okra',
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.refresh(userTheaterBookingsProvider),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Okra',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsList(List<TheaterBookingModel> bookings) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return _buildBookingCard(booking);
      },
    );
  }

  Widget _buildBookingCard(TheaterBookingModel booking) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showBookingDetails(booking),
          borderRadius: BorderRadius.circular(12),
          child: _buildTicketCard(booking),
        ),
      ),
    );
  }

  Widget _buildTicketCard(TheaterBookingModel booking) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            spreadRadius: 0,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Main ticket content
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with theater name and status
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.theaterName ?? 'Theater',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Okra',
                              color: Colors.black87,
                            ),
                          ),
                          if (booking.screenName != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              booking.screenName!,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Okra',
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            'BOOKING ID: ${booking.id.substring(0, 8).toUpperCase()}',
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'Okra',
                              color: Colors.grey[600],
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(booking.bookingStatus).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _getStatusColor(booking.bookingStatus),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        booking.bookingStatus.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Okra',
                          color: _getStatusColor(booking.bookingStatus),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Ticket details row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left side - Theater image and details
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Theater image
                          Container(
                            width: double.infinity,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.grey[50],
                              border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                            child: booking.theaterImages?.isNotEmpty == true
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: booking.theaterImages!.first,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => const Center(
                                        child: CircularProgressIndicator(
                                          color: AppTheme.primaryColor,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Icon(
                                        Icons.movie_creation_outlined,
                                        color: Colors.grey[400],
                                        size: 40,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.movie_creation_outlined,
                                    color: Colors.grey[400],
                                    size: 40,
                                  ),
                          ),

                          const SizedBox(height: 14),

                          // Date and time
                          _buildTicketDetail('DATE', DateFormat('MMM dd, yyyy').format(booking.bookingDate)),
                          const SizedBox(height: 8),
                          _buildTicketDetail('TIME', _formatTimeRange(booking.startTime, booking.endTime)),
                          const SizedBox(height: 8),
                          _buildTicketDetail('GUESTS', '${booking.numberOfPeople} People'),
                        ],
                      ),
                    ),

                    const SizedBox(width: 18),

                    // Right side - QR Code and price
                    Column(
                      children: [
                        // QR Code
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.primaryColor.withValues(alpha: 0.2),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                spreadRadius: 0,
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: QrImageView(
                              data: booking.id,
                              version: QrVersions.auto,
                              size: 74,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Colors.black87,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Price — show breakdown if pending amount exists
                        if (booking.pendingAmount > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  '₹${_formatAmount(booking.userAdvancePayment)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Okra',
                                    color: Colors.green[700],
                                    height: 1.2,
                                  ),
                                ),
                                Text(
                                  'Advance Paid',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontFamily: 'Okra',
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  height: 1,
                                  color: Colors.orange.withValues(alpha: 0.25),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '₹${_formatAmount(booking.pendingAmount)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Okra',
                                    color: Colors.orange[700],
                                    height: 1.2,
                                  ),
                                ),
                                Text(
                                  'Pay remaining at venue',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontFamily: 'Okra',
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '₹${_formatAmount(booking.totalAmount)}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Okra',
                                    color: AppTheme.primaryColor,
                                    height: 1.2,
                                  ),
                                ),
                                Text(
                                  'Total',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'Okra',
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),

                if (booking.addons?.isNotEmpty == true) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${booking.addons!.length} Add-ons included',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Okra',
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Dotted line separator
          _buildDottedLine(),

          // Pay Remaining button (only for confirmed bookings with pending amount)
          if (booking.pendingAmount > 0 && booking.bookingStatus == 'confirmed')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showPayRemainingSheet(booking),
                  icon: const Icon(Icons.payment, size: 18),
                  label: Text(
                    'Pay ₹${_formatAmount(booking.pendingAmount)} Remaining',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Okra',
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),

          // Navigation section
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Theater Location',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Okra',
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking.theaterAddress ?? 'Address not available',
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'Okra',
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _navigateToTheater(booking),
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text(
                    'Navigate',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Okra',
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Formats a raw Postgres time string (e.g. "18:30:00") to "6:30 PM"
  String _formatTime(String rawTime) {
    try {
      final parts = rawTime.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final dt = DateTime(2000, 1, 1, hour, minute);
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return rawTime;
    }
  }

  String _formatTimeRange(String start, String end) =>
      '${_formatTime(start)} - ${_formatTime(end)}';

  Widget _buildTicketDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            fontFamily: 'Okra',
            color: Colors.grey[600],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Okra',
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildDottedLine() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(
          50,
          (index) => Expanded(
            child: Container(
              height: 1,
              color: index.isEven ? Colors.grey[300] : Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToTheater(TheaterBookingModel booking) async {
    try {
      final String googleMapsUrl;
      final String appleMapsUrl;

      if (booking.theaterLatitude != null && booking.theaterLongitude != null) {
        // Use precise coordinates for pin-accurate navigation
        final lat = booking.theaterLatitude!;
        final lng = booking.theaterLongitude!;
        final label = Uri.encodeComponent(booking.theaterName ?? 'Theater');
        googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
        appleMapsUrl = 'http://maps.apple.com/?ll=$lat,$lng&q=$label';
      } else if (booking.theaterAddress != null && booking.theaterAddress!.isNotEmpty) {
        // Fallback to text search if coordinates unavailable
        final query = Uri.encodeComponent(booking.theaterAddress!);
        googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$query';
        appleMapsUrl = 'http://maps.apple.com/?q=$query';
      } else {
        _showSnackBar('Theater location not available', Colors.orange);
        return;
      }

      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(Uri.parse(appleMapsUrl))) {
        await launchUrl(Uri.parse(appleMapsUrl), mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('No maps app available', Colors.orange);
      }
    } catch (e) {
      _showSnackBar('Unable to open maps', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontFamily: 'Okra'),
          ),
          backgroundColor: color,
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'no_show':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(0);
  }

  void _showBookingDetails(TheaterBookingModel booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header Section with Status Badge
              Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Booking Details',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Okra',
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            booking.theaterName ?? 'Theater',
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Okra',
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(booking.bookingStatus).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _getStatusColor(booking.bookingStatus),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        booking.bookingStatus.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Okra',
                          color: _getStatusColor(booking.bookingStatus),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 20),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // QR Code Section with enhanced styling
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.primaryColor.withValues(alpha: 0.05),
                                Colors.purple.withValues(alpha: 0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.primaryColor.withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: QrImageView(
                                  data: booking.id,
                                  version: QrVersions.auto,
                                  size: 180,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: Colors.black87,
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.qr_code_scanner,
                                    size: 16,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Show this QR code at the theater',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Okra',
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Booking Information Section
                      _buildSectionHeader('Booking Information'),
                      _buildInfoCard([
                        _buildDetailRow('Theater', booking.theaterName ?? 'N/A', Icons.theater_comedy),
                        if (booking.screenName != null)
                          _buildDetailRow('Screen', booking.screenName!, Icons.tv),
                        _buildDetailRow('Date', DateFormat('MMM dd, yyyy').format(booking.bookingDate), Icons.calendar_today),
                        _buildDetailRow('Time', _formatTimeRange(booking.startTime, booking.endTime), Icons.access_time),
                        _buildDetailRow('People', booking.numberOfPeople.toString(), Icons.people),
                      ]),

                      const SizedBox(height: 20),

                      // Contact Information Section
                      _buildSectionHeader('Contact Details'),
                      _buildInfoCard([
                        _buildDetailRow('Name', booking.contactName, Icons.person),
                        _buildDetailRow('Phone', booking.contactPhone, Icons.phone),
                        if (booking.contactEmail != null)
                          _buildDetailRow('Email', booking.contactEmail!, Icons.email),
                      ]),

                      const SizedBox(height: 20),

                      // Payment Information Section
                      _buildSectionHeader('Payment Information'),
                      _buildInfoCard([
                        _buildDetailRow('Total Amount', '₹${_formatAmount(booking.totalAmount)}', Icons.currency_rupee,
                          valueStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Okra',
                            color: AppTheme.primaryColor,
                          )),
                      ]),

                      const SizedBox(height: 20),

                      // Additional Information Section
                      _buildSectionHeader('Additional Details'),
                      _buildInfoCard([
                        _buildDetailRow('Booking ID', booking.id, Icons.confirmation_number),
                        _buildDetailRow('Person Celebrating', booking.personName ?? 'Not specified', Icons.person_outline),
                        _buildDetailRow('Occasion', booking.occasionName ?? 'Not specified', Icons.event),
                        _buildDetailRow('Banner Message', booking.celebrationName ?? 'Not specified', Icons.celebration),
                        _buildDetailRow('Special Requests', booking.specialRequests ?? 'None', Icons.note),
                        if (booking.createdAt != null)
                          _buildDetailRow('Booked On', DateFormat('MMM dd, yyyy hh:mm a').format(booking.createdAt!), Icons.schedule),
                      ]),
                      if (booking.userAdvancePayment > 0) ...[
                        const SizedBox(height: 16),
                        _buildSectionHeader('Payment Breakdown'),
                        _buildInfoCard([
                          _buildDetailRow('Advance Paid', '₹${booking.userAdvancePayment.toStringAsFixed(0)}', Icons.payments_outlined),
                          _buildDetailRow('Remaining at Venue', '₹${booking.pendingAmount.toStringAsFixed(0)}', Icons.pending_outlined),
                          _buildDetailRow('Total', '₹${booking.totalAmount.toStringAsFixed(0)}', Icons.receipt_long_outlined),
                        ]),
                      ],

                      const SizedBox(height: 24),

                      // Theater Address and Navigation
                      if (booking.theaterAddress != null && booking.theaterAddress!.isNotEmpty) ...[
                        _buildSectionHeader('Location'),
                        _buildInfoCard([
                          _buildDetailRow('Theater Location', booking.theaterAddress!, Icons.location_on),
                        ]),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryColor,
                                AppTheme.primaryColor.withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () => _navigateToTheater(booking),
                            icon: const Icon(Icons.directions, size: 20),
                            label: const Text(
                              'Theater Location',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Okra',
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      if (booking.addons?.isNotEmpty == true) ...[
                        _buildSectionHeader('Add-ons & Services'),
                        ...booking.addons!.map((addon) => _buildAddonItem(addon)),
                        const SizedBox(height: 24),
                      ],

                      if (booking.bookingStatus == 'confirmed') ...[
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () => _cancelBooking(booking.id),
                            icon: const Icon(Icons.cancel_outlined, size: 20),
                            label: const Text(
                              'Cancel Booking',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Okra',
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.red,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddonItem(TheaterBookingAddonModel addon) {
    final hasImage =
        addon.addonImageUrl != null && addon.addonImageUrl!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Image thumbnail — always shown; tappable when URL exists
          GestureDetector(
            onTap: hasImage
                ? () => _showFullScreenImage(context, addon.addonImageUrl!)
                : null,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[100],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: hasImage
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: addon.addonImageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Icon(
                              Icons.card_giftcard_outlined,
                              size: 24,
                              color: Colors.grey[400],
                            ),
                          ),
                          // Zoom hint overlay
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Icon(
                                Icons.zoom_in,
                                size: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Icon(
                        Icons.card_giftcard_outlined,
                        size: 26,
                        color: Colors.grey[400],
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  addon.addonName ?? 'Add-on',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Okra',
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Qty: ${addon.quantity} × ₹${addon.unitPrice.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Okra',
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₹${addon.totalPrice.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'Okra',
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // Dismiss on tap outside image
            GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              child: Container(color: Colors.transparent),
            ),
            Center(
              child: GestureDetector(
                // Prevent dismiss when tapping the image itself
                onTap: () {},
                child: Hero(
                  tag: imageUrl,
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white,
                        size: 60,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 40,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'Okra',
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon, {
    TextStyle? valueStyle,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 16,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Okra',
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: valueStyle ??
                      TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Okra',
                        color: valueColor ?? Colors.black87,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPayRemainingSheet(TheaterBookingModel booking) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.payment, size: 36, color: Colors.orange[700]),
              ),
              const SizedBox(height: 16),
              const Text(
                'Remaining Payment',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Okra',
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                booking.theaterName ?? 'Theater',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Okra',
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              // Payment breakdown
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    _buildPayRow('Total Amount', '₹${_formatAmount(booking.totalAmount)}', Colors.black87),
                    const SizedBox(height: 8),
                    _buildPayRow('Advance Paid', '- ₹${_formatAmount(booking.userAdvancePayment)}', Colors.green[700]!),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Divider(color: Colors.grey[300], height: 1),
                    ),
                    _buildPayRow(
                      'Amount Due',
                      '₹${_formatAmount(booking.pendingAmount)}',
                      Colors.orange[700]!,
                      bold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Please pay the remaining amount at the venue during your visit.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Okra',
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Got it',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Okra',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPayRow(String label, String value, Color valueColor, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontFamily: 'Okra',
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 18 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            fontFamily: 'Okra',
            color: valueColor,
          ),
        ),
      ],
    );
  }

  void _cancelBooking(String bookingId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Cancel Booking',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'Okra',
            ),
          ),
          content: const Text(
            'Are you sure you want to cancel this theater booking? This action cannot be undone.',
            style: TextStyle(fontFamily: 'Okra'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'No',
                style: TextStyle(color: Colors.grey[600], fontFamily: 'Okra'),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _performCancellation(bookingId);
              },
              child: Text(
                'Yes, Cancel',
                style: TextStyle(
                  color: Colors.red[600],
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Okra',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performCancellation(String bookingId) async {
    try {
      await ref.read(theaterBookingCancellationProvider.notifier).cancelBooking(bookingId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Booking cancelled successfully',
              style: TextStyle(fontFamily: 'Okra'),
            ),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh the bookings list
        ref.invalidate(userTheaterBookingsProvider);
        
        // Close the modal
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to cancel booking: ${e.toString()}',
              style: const TextStyle(fontFamily: 'Okra'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
