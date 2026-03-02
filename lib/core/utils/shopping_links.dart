/// Utility for building affiliate / deep-link shopping URLs.
class ShoppingLinks {
  ShoppingLinks._();

  /// Amazon search URL for a given query string.
  static String buildAmazonLink(String query) {
    final encoded = Uri.encodeComponent(query);
    return 'https://www.amazon.com/s?k=$encoded';
  }

  /// Google Shopping search URL.
  static String buildGoogleShoppingLink(String query) {
    final encoded = Uri.encodeComponent(query);
    return 'https://www.google.com/search?tbm=shop&q=$encoded';
  }

  /// Zara search URL.
  static String buildZaraLink(String query) {
    // Zara's search uses a specific path format.
    final encoded = Uri.encodeComponent(query);
    return 'https://www.zara.com/us/en/search?searchTerm=$encoded';
  }

  /// H&M search URL.
  static String buildHmLink(String query) {
    final encoded = Uri.encodeComponent(query);
    return 'https://www2.hm.com/en_us/search-results.html?q=$encoded';
  }

  /// Target search URL.
  static String buildTargetLink(String query) {
    final encoded = Uri.encodeComponent(query);
    return 'https://www.target.com/s?searchTerm=$encoded';
  }

  /// Returns a list of all shop links for quick access.
  static List<ShopLink> allLinks(String query) {
    return [
      ShopLink(name: 'Amazon', url: buildAmazonLink(query), icon: '🛒'),
      ShopLink(name: 'Google', url: buildGoogleShoppingLink(query), icon: '🔍'),
      ShopLink(name: 'Zara', url: buildZaraLink(query), icon: '🏬'),
      ShopLink(name: 'H&M', url: buildHmLink(query), icon: '👗'),
      ShopLink(name: 'Target', url: buildTargetLink(query), icon: '🎯'),
    ];
  }
}

/// A simple value object for a shop link.
class ShopLink {
  const ShopLink({
    required this.name,
    required this.url,
    required this.icon,
  });

  final String name;
  final String url;
  final String icon;
}
