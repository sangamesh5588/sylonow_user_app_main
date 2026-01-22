import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/onboarding_providers.dart';
import '../../home/providers/filter_providers.dart';

class DateScreen extends ConsumerStatefulWidget {
  static const String routeName = '/onboarding/date';

  const DateScreen({super.key});

  @override
  ConsumerState<DateScreen> createState() => _DateScreenState();
}

class _DateScreenState extends ConsumerState<DateScreen> {
  DateTime? _selectedDate;
  final _dateFormatter = DateFormat('MMMM d, y');
  bool _isLoading = false;

  // Filter states
  String _selectedSort = 'high_to_low';
  double _minPrice = 0;
  double _maxPrice = 10000;
  double _maxDistance = 20; // Default to 20km to match popularNearbyServicesProvider
  List<String> _selectedCategories = [];
  bool _nearbyOnly = false;

  Future<void> _selectDate() async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    DateTime tempSelectedDate = _selectedDate ?? today;
    
    // Ensure tempSelectedDate is not before today
    if (tempSelectedDate.isBefore(today)) {
      tempSelectedDate = today;
    }
    
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                        fontFamily: 'Okra',
                      ),
                    ),
                  ),
                  Text(
                    'Select Date',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Okra',
                      color: Colors.black,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedDate = tempSelectedDate;
                      });
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Done',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Okra',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Cupertino Date Picker
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: tempSelectedDate,
                  minimumDate: today,
                  maximumDate: today.add(const Duration(days: 365 * 2)),
                  onDateTimeChanged: (DateTime newDate) {
                    tempSelectedDate = newDate;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _continue() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final dateString = _selectedDate!.toIso8601String();
      await ref.read(onboardingControllerProvider.notifier)
          .updateCelebrationDate(dateString);
      
      // Complete onboarding after saving the date
      await ref.read(onboardingControllerProvider.notifier).completeOnboarding();
      
      if (mounted) {
        // Navigate to home screen with no back navigation
        context.go(AppConstants.homeRoute);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save date: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _skip() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Complete onboarding even when skipping date selection
      await ref.read(onboardingControllerProvider.notifier).completeOnboarding();
      
      if (mounted) {
        // Navigate to home screen with no back navigation
        context.go(AppConstants.homeRoute);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 32),
      child: Row(
        children: [
          // Step 1 - Completed
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Step 2 - Completed
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Step 3 - Active
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 
                        MediaQuery.of(context).viewInsets.bottom - 
                        MediaQuery.of(context).viewPadding.top - 48,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  // Progress Indicator
                  _buildProgressIndicator(),
                  
                  // Main Content
                  Expanded(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        
                        // Illustration
                        Container(
                          height: 200,
                          padding: const EdgeInsets.all(20),
                          child: Image.asset(
                            'assets/images/date_picker.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Title
                        Text(
                          'When is your celebration?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Okra',
                            color: Colors.black,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Subtitle
                        Text(
                          'We\'ll help you get everything ready on time.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'Okra',
                            color: Colors.grey[600],
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Date Input Field
                        GestureDetector(
                          onTap: _selectDate,
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 16),
                                Icon(
                                  Icons.calendar_today,
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _selectedDate != null
                                        ? _dateFormatter.format(_selectedDate!)
                                        : 'dd/mm/yyyy',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontFamily: 'Okra',
                                      color: _selectedDate != null
                                          ? Colors.black
                                          : Colors.grey[400],
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 16),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Filter Chips
                        SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: 6, // 6 filters: Sort, Price, Distance, Categories, Nearby, Clear All
                            separatorBuilder: (context, index) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              // Filter 0: High to Low
                              if (index == 0) {
                                final isSelected = _selectedSort == 'high_to_low';
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedSort = 'high_to_low';
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppTheme.primaryColor : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: isSelected ? AppTheme.primaryColor : Colors.grey[200]!,
                                      ),
                                    ),
                                    child: Text(
                                      'High to Low',
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.grey[700],
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        fontFamily: 'Okra',
                                      ),
                                    ),
                                  ),
                                );
                              }

                              // Filter 1: Low to High
                              if (index == 1) {
                                final isSelected = _selectedSort == 'low_to_high';
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedSort = 'low_to_high';
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppTheme.primaryColor : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: isSelected ? AppTheme.primaryColor : Colors.grey[200]!,
                                      ),
                                    ),
                                    child: Text(
                                      'Low to High',
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.grey[700],
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        fontFamily: 'Okra',
                                      ),
                                    ),
                                  ),
                                );
                              }

                              // Filter 2: Price
                              if (index == 2) {
                                final hasPrice = _minPrice > 0 || _maxPrice < 10000;
                                return GestureDetector(
                                  onTap: () => _showPriceSheet(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: hasPrice ? AppTheme.primaryColor : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: hasPrice ? AppTheme.primaryColor : Colors.grey[200]!,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.currency_rupee,
                                          size: 16,
                                          color: hasPrice ? Colors.white : Colors.grey[700],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          hasPrice ? '₹${_minPrice.round()}-${_maxPrice.round()}' : 'Price',
                                          style: TextStyle(
                                            color: hasPrice ? Colors.white : Colors.grey[700],
                                            fontSize: 12,
                                            fontWeight: hasPrice ? FontWeight.w600 : FontWeight.w500,
                                            fontFamily: 'Okra',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              // Filter 3: Distance
                              if (index == 3) {
                                final hasDistance = _maxDistance < 20;
                                return GestureDetector(
                                  onTap: () => _showDistanceSheet(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: hasDistance ? AppTheme.primaryColor : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: hasDistance ? AppTheme.primaryColor : Colors.grey[200]!,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 16,
                                          color: hasDistance ? Colors.white : Colors.grey[700],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          hasDistance ? '${_maxDistance.round()}km' : 'Distance',
                                          style: TextStyle(
                                            color: hasDistance ? Colors.white : Colors.grey[700],
                                            fontSize: 12,
                                            fontWeight: hasDistance ? FontWeight.w600 : FontWeight.w500,
                                            fontFamily: 'Okra',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              // Filter 4: Nearby
                              if (index == 4) {
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _nearbyOnly = !_nearbyOnly;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _nearbyOnly ? AppTheme.primaryColor : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: _nearbyOnly ? AppTheme.primaryColor : Colors.grey[200]!,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.near_me,
                                          size: 16,
                                          color: _nearbyOnly ? Colors.white : Colors.grey[700],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Nearby',
                                          style: TextStyle(
                                            color: _nearbyOnly ? Colors.white : Colors.grey[700],
                                            fontSize: 12,
                                            fontWeight: _nearbyOnly ? FontWeight.w600 : FontWeight.w500,
                                            fontFamily: 'Okra',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              // Filter 5: Categories
                              if (index == 5) {
                                final hasCategories = _selectedCategories.isNotEmpty;
                                return GestureDetector(
                                  onTap: () => _showCategorySheet(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: hasCategories ? AppTheme.primaryColor : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: hasCategories ? AppTheme.primaryColor : Colors.grey[200]!,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.category_outlined,
                                          size: 16,
                                          color: hasCategories ? Colors.white : Colors.grey[700],
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          hasCategories
                                              ? '${_selectedCategories.length} ${_selectedCategories.length == 1 ? 'Category' : 'Categories'}'
                                              : 'Categories',
                                          style: TextStyle(
                                            color: hasCategories ? Colors.white : Colors.grey[700],
                                            fontSize: 12,
                                            fontWeight: hasCategories ? FontWeight.w600 : FontWeight.w500,
                                            fontFamily: 'Okra',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              return const SizedBox.shrink();
                            },
                          ),
                        ),

                        const Spacer(),
                      ],
                    ),
                  ),
                  
                  // Continue Button
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _continue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedDate != null 
                              ? const Color(0xFF1E3A5F)
                              : Colors.grey[300],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Continue',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Okra',
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPriceSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        double tempMinPrice = _minPrice;
        double tempMaxPrice = _maxPrice;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Price Range',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Okra',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${tempMinPrice.round()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Okra',
                        ),
                      ),
                      Text(
                        '₹${tempMaxPrice.round()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Okra',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  RangeSlider(
                    values: RangeValues(tempMinPrice, tempMaxPrice),
                    min: 0,
                    max: 10000,
                    divisions: 100,
                    activeColor: AppTheme.primaryColor,
                    inactiveColor: Colors.grey[300],
                    labels: RangeLabels(
                      '₹${tempMinPrice.round()}',
                      '₹${tempMaxPrice.round()}',
                    ),
                    onChanged: (values) {
                      setModalState(() {
                        tempMinPrice = values.start;
                        tempMaxPrice = values.end;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _minPrice = 0;
                              _maxPrice = 10000;
                            });
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Clear',
                            style: TextStyle(
                              color: Colors.black87,
                              fontFamily: 'Okra',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _minPrice = tempMinPrice;
                              _maxPrice = tempMaxPrice;
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Apply',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Okra',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDistanceSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        double tempDistance = _maxDistance;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Maximum Distance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Okra',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '${tempDistance.round()} km',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Okra',
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: tempDistance,
                    min: 1,
                    max: 20,
                    divisions: 19,
                    activeColor: AppTheme.primaryColor,
                    inactiveColor: Colors.grey[300],
                    label: '${tempDistance.round()} km',
                    onChanged: (value) {
                      setModalState(() {
                        tempDistance = value;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _maxDistance = 20;
                            });
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Clear',
                            style: TextStyle(
                              color: Colors.black87,
                              fontFamily: 'Okra',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _maxDistance = tempDistance;
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Apply',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Okra',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCategorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final categoriesAsync = ref.watch(availableCategoriesProvider);

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Select Categories',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Okra',
                          ),
                        ),
                      ),
                      if (_selectedCategories.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedCategories = [];
                            });
                          },
                          child: const Text(
                            'Clear All',
                            style: TextStyle(
                              color: Color(0xFF1E3A5F),
                              fontFamily: 'Okra',
                            ),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                categoriesAsync.when(
                  data: (categories) {
                    if (categories.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No categories available',
                          style: TextStyle(
                            color: Colors.grey,
                            fontFamily: 'Okra',
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final isSelected = _selectedCategories.contains(category);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedCategories.remove(category);
                                } else {
                                  _selectedCategories.add(category);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? AppTheme.primaryColor : Colors.grey[200]!,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      category,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        color: isSelected ? AppTheme.primaryColor : Colors.black87,
                                        fontFamily: 'Okra',
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF1E3A5F),
                                      size: 22,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF1E3A5F)),
                    ),
                  ),
                  error: (error, stack) => Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Error loading categories',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontFamily: 'Okra',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}
