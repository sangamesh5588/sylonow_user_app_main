/// Utility class for applying consistent price rounding logic across the app
/// This ensures ALL prices end with 99 (pricing psychology)
class PriceRounding {
  /// Rounds ALL prices to end with 99 (pricing psychology)
  ///
  /// Always rounds UP to the next X99 to ensure consistent pricing across the app
  /// This matches PriceCalculator.formatPriceAsInt logic to prevent double rounding
  ///
  /// Examples:
  /// - 510 → 599
  /// - 523 → 599
  /// - 560 → 599
  /// - 678 → 699
  /// - 16549 → 16599
  static double applyFinalRounding(double amount) {
    // Handle edge cases
    if (amount <= 0) {
      return 0.0;
    }

    // Round to nearest integer first
    int basePrice = amount.round();

    // Get last two digits
    int lastTwoDigits = basePrice % 100;

    // If already ends with 99, keep it
    if (lastTwoDigits == 99) {
      return basePrice.toDouble();
    }

    // Always round UP to next X99
    int currentHundred = basePrice ~/ 100;
    basePrice = (currentHundred + 1) * 100 - 1;

    return basePrice.toDouble();
  }

  /// Rounds a nullable price, returns null if input is null
  static double? applyFinalRoundingNullable(double? amount) {
    if (amount == null) return null;
    return applyFinalRounding(amount);
  }

  /// Formats a price with currency symbol and proper rounding
  static String formatPrice(double amount, {String currencySymbol = '₹'}) {
    final rounded = applyFinalRounding(amount);
    return '$currencySymbol${rounded.toStringAsFixed(2)}';
  }

  /// Formats a nullable price with currency symbol and proper rounding
  static String? formatPriceNullable(double? amount, {String currencySymbol = '₹'}) {
    if (amount == null) return null;
    return formatPrice(amount, currencySymbol: currencySymbol);
  }
}
