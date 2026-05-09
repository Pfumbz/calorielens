import 'dart:io';

/// Detects the device locale and returns the correct pricing details.
/// Falls back to USD if the country is not in the map.
class PricingInfo {
  final String symbol;
  final String amount;
  final String currency;
  final String fullPrice;   // e.g. "R79.99/month"
  final String countryCode;

  const PricingInfo({
    required this.symbol,
    required this.amount,
    required this.currency,
    required this.fullPrice,
    required this.countryCode,
  });
}

PricingInfo getLocalPricing() {
  // Platform.localeName returns e.g. "en_ZA", "en_GB", "af_ZA"
  final locale = Platform.localeName;
  final parts = locale.split('_');
  // Country code is the last segment (or second segment)
  final country = parts.length >= 2 ? parts.last.toUpperCase() : '';

  return _pricingMap[country] ?? _pricingMap['US']!;
}

/// Country code → pricing details
const Map<String, PricingInfo> _pricingMap = {
  // ── Africa ──────────────────────────────────────────────────────────────
  'ZA': PricingInfo(symbol: 'R',    amount: '48.99',   currency: 'ZAR', fullPrice: 'R48.99/month',     countryCode: 'ZA'),
  'NG': PricingInfo(symbol: '₦',   amount: '3,999',   currency: 'NGN', fullPrice: '₦3,999/month',     countryCode: 'NG'),
  'KE': PricingInfo(symbol: 'KSh', amount: '649',     currency: 'KES', fullPrice: 'KSh649/month',     countryCode: 'KE'),
  'GH': PricingInfo(symbol: 'GH₵', amount: '59.99',   currency: 'GHS', fullPrice: 'GH₵59.99/month',   countryCode: 'GH'),
  'EG': PricingInfo(symbol: 'E£',  amount: '159',     currency: 'EGP', fullPrice: 'E£159/month',      countryCode: 'EG'),
  'TZ': PricingInfo(symbol: 'TSh', amount: '12,999',  currency: 'TZS', fullPrice: 'TSh12,999/month',  countryCode: 'TZ'),
  'UG': PricingInfo(symbol: 'USh', amount: '18,999',  currency: 'UGX', fullPrice: 'USh18,999/month',  countryCode: 'UG'),

  // ── Europe ───────────────────────────────────────────────────────────────
  'GB': PricingInfo(symbol: '£',   amount: '4.99',    currency: 'GBP', fullPrice: '£4.99/month',      countryCode: 'GB'),
  'DE': PricingInfo(symbol: '€',   amount: '5.49',    currency: 'EUR', fullPrice: '€5.49/month',      countryCode: 'DE'),
  'FR': PricingInfo(symbol: '€',   amount: '5.49',    currency: 'EUR', fullPrice: '€5.49/month',      countryCode: 'FR'),
  'NL': PricingInfo(symbol: '€',   amount: '5.49',    currency: 'EUR', fullPrice: '€5.49/month',      countryCode: 'NL'),
  'ES': PricingInfo(symbol: '€',   amount: '5.49',    currency: 'EUR', fullPrice: '€5.49/month',      countryCode: 'ES'),
  'IT': PricingInfo(symbol: '€',   amount: '5.49',    currency: 'EUR', fullPrice: '€5.49/month',      countryCode: 'IT'),

  // ── Americas ─────────────────────────────────────────────────────────────
  'US': PricingInfo(symbol: '\$',  amount: '4.99',    currency: 'USD', fullPrice: '\$4.99/month',     countryCode: 'US'),
  'CA': PricingInfo(symbol: 'C\$', amount: '6.99',    currency: 'CAD', fullPrice: 'C\$6.99/month',    countryCode: 'CA'),
  'BR': PricingInfo(symbol: 'R\$', amount: '24.99',   currency: 'BRL', fullPrice: 'R\$24.99/month',   countryCode: 'BR'),
  'MX': PricingInfo(symbol: 'MX\$',amount: '89',      currency: 'MXN', fullPrice: 'MX\$89/month',     countryCode: 'MX'),

  // ── Asia-Pacific ─────────────────────────────────────────────────────────
  'AU': PricingInfo(symbol: 'A\$', amount: '7.99',    currency: 'AUD', fullPrice: 'A\$7.99/month',    countryCode: 'AU'),
  'NZ': PricingInfo(symbol: 'NZ\$',amount: '8.49',    currency: 'NZD', fullPrice: 'NZ\$8.49/month',   countryCode: 'NZ'),
  'IN': PricingInfo(symbol: '₹',   amount: '399',     currency: 'INR', fullPrice: '₹399/month',       countryCode: 'IN'),
  'SG': PricingInfo(symbol: 'S\$', amount: '6.99',    currency: 'SGD', fullPrice: 'S\$6.99/month',    countryCode: 'SG'),
  'AE': PricingInfo(symbol: 'AED', amount: '18.99',   currency: 'AED', fullPrice: 'AED18.99/month',   countryCode: 'AE'),
};
