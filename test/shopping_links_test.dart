// shopping_links_test.dart
// Unit tests for ShoppingLinks URL builders and ShopLink value object.
// Pure Dart — no Flutter dependencies.

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_designer_assist/core/utils/shopping_links.dart';

void main() {
  // ---------------------------------------------------------------------------
  group('ShoppingLinks.buildAmazonLink', () {
    test('simple query → correct base URL', () {
      final url = ShoppingLinks.buildAmazonLink('blue jeans');
      expect(url, startsWith('https://www.amazon.com/s?k='));
    });

    test('spaces encoded as %20 or +', () {
      final url = ShoppingLinks.buildAmazonLink('blue jeans');
      // Uri.encodeComponent encodes spaces as %20
      expect(url, contains('blue%20jeans'));
    });

    test('special characters encoded', () {
      final url = ShoppingLinks.buildAmazonLink('shirt & tie');
      expect(url, isNot(contains('&tie'))); // & must be encoded
      expect(url, contains('%26'));
    });

    test('single word query — no encoding needed', () {
      final url = ShoppingLinks.buildAmazonLink('dress');
      expect(url, 'https://www.amazon.com/s?k=dress');
    });

    test('empty query → empty k= param', () {
      final url = ShoppingLinks.buildAmazonLink('');
      expect(url, 'https://www.amazon.com/s?k=');
    });

    test('query with plus sign encoded', () {
      final url = ShoppingLinks.buildAmazonLink('2+1 shirt');
      expect(url, contains('%2B'));
    });

    test('returns valid Uri parseable string', () {
      final url = ShoppingLinks.buildAmazonLink('women\'s floral blouse');
      expect(() => Uri.parse(url), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  group('ShoppingLinks.buildGoogleShoppingLink', () {
    test('correct base URL and search params', () {
      final url = ShoppingLinks.buildGoogleShoppingLink('blue dress');
      expect(url, startsWith('https://www.google.com/search?tbm=shop&q='));
    });

    test('spaces encoded in query', () {
      final url = ShoppingLinks.buildGoogleShoppingLink('blue dress');
      expect(url, contains('blue%20dress'));
    });

    test('tbm=shop preserved in url', () {
      final url = ShoppingLinks.buildGoogleShoppingLink('anything');
      expect(url, contains('tbm=shop'));
    });

    test('empty query keeps structure intact', () {
      final url = ShoppingLinks.buildGoogleShoppingLink('');
      expect(url, 'https://www.google.com/search?tbm=shop&q=');
    });

    test('returns parseable URI', () {
      final url = ShoppingLinks.buildGoogleShoppingLink('summer jacket');
      expect(() => Uri.parse(url), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  group('ShoppingLinks.buildZaraLink', () {
    test('correct base URL and param', () {
      final url = ShoppingLinks.buildZaraLink('midi skirt');
      expect(url, startsWith('https://www.zara.com/us/en/search?searchTerm='));
    });

    test('spaces encoded', () {
      final url = ShoppingLinks.buildZaraLink('midi skirt');
      expect(url, contains('midi%20skirt'));
    });

    test('single word query', () {
      final url = ShoppingLinks.buildZaraLink('blazer');
      expect(url, 'https://www.zara.com/us/en/search?searchTerm=blazer');
    });

    test('returns parseable URI', () {
      final url = ShoppingLinks.buildZaraLink('floral top');
      expect(() => Uri.parse(url), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  group('ShoppingLinks.buildHmLink', () {
    test('correct base URL', () {
      final url = ShoppingLinks.buildHmLink('white shirt');
      expect(url, startsWith('https://www2.hm.com/en_us/search-results.html?q='));
    });

    test('spaces encoded', () {
      final url = ShoppingLinks.buildHmLink('white shirt');
      expect(url, contains('white%20shirt'));
    });

    test('single word query', () {
      final url = ShoppingLinks.buildHmLink('jeans');
      expect(url, 'https://www2.hm.com/en_us/search-results.html?q=jeans');
    });

    test('returns parseable URI', () {
      final url = ShoppingLinks.buildHmLink('casual dress');
      expect(() => Uri.parse(url), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  group('ShoppingLinks.buildTargetLink', () {
    test('correct base URL', () {
      final url = ShoppingLinks.buildTargetLink('running shoes');
      expect(url, startsWith('https://www.target.com/s?searchTerm='));
    });

    test('spaces encoded', () {
      final url = ShoppingLinks.buildTargetLink('running shoes');
      expect(url, contains('running%20shoes'));
    });

    test('single word query', () {
      final url = ShoppingLinks.buildTargetLink('sneakers');
      expect(url, 'https://www.target.com/s?searchTerm=sneakers');
    });

    test('returns parseable URI', () {
      final url = ShoppingLinks.buildTargetLink('graphic tee');
      expect(() => Uri.parse(url), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  group('ShoppingLinks.allLinks', () {
    test('returns exactly 5 links', () {
      expect(ShoppingLinks.allLinks('jacket'), hasLength(5));
    });

    test('first link is Amazon', () {
      expect(ShoppingLinks.allLinks('shoes').first.name, 'Amazon');
    });

    test('links in order: Amazon, Google, Zara, H&M, Target', () {
      final names = ShoppingLinks.allLinks('bag').map((l) => l.name).toList();
      expect(names, ['Amazon', 'Google', 'Zara', 'H&M', 'Target']);
    });

    test('each link has non-empty url', () {
      for (final link in ShoppingLinks.allLinks('coat')) {
        expect(link.url, isNotEmpty);
      }
    });

    test('each link has non-empty name', () {
      for (final link in ShoppingLinks.allLinks('coat')) {
        expect(link.name, isNotEmpty);
      }
    });

    test('each link has non-empty icon', () {
      for (final link in ShoppingLinks.allLinks('coat')) {
        expect(link.icon, isNotEmpty);
      }
    });

    test('Amazon url matches buildAmazonLink', () {
      const query = 'wool coat';
      final links = ShoppingLinks.allLinks(query);
      final amazon = links.firstWhere((l) => l.name == 'Amazon');
      expect(amazon.url, ShoppingLinks.buildAmazonLink(query));
    });

    test('Google url matches buildGoogleShoppingLink', () {
      const query = 'wool coat';
      final links = ShoppingLinks.allLinks(query);
      final google = links.firstWhere((l) => l.name == 'Google');
      expect(google.url, ShoppingLinks.buildGoogleShoppingLink(query));
    });

    test('Zara url matches buildZaraLink', () {
      const query = 'summer dress';
      final links = ShoppingLinks.allLinks(query);
      final zara = links.firstWhere((l) => l.name == 'Zara');
      expect(zara.url, ShoppingLinks.buildZaraLink(query));
    });

    test('H&M url matches buildHmLink', () {
      const query = 'blue jeans';
      final links = ShoppingLinks.allLinks(query);
      final hm = links.firstWhere((l) => l.name == 'H&M');
      expect(hm.url, ShoppingLinks.buildHmLink(query));
    });

    test('Target url matches buildTargetLink', () {
      const query = 'sneakers';
      final links = ShoppingLinks.allLinks(query);
      final target = links.firstWhere((l) => l.name == 'Target');
      expect(target.url, ShoppingLinks.buildTargetLink(query));
    });

    test('all urls are parseable URIs', () {
      for (final link in ShoppingLinks.allLinks('floral midi dress')) {
        expect(() => Uri.parse(link.url), returnsNormally);
      }
    });

    test('query with special chars — all urls still parseable', () {
      for (final link in ShoppingLinks.allLinks('men\'s & women\'s jackets')) {
        expect(() => Uri.parse(link.url), returnsNormally);
      }
    });

    test('empty query — returns 5 links with empty encoded params', () {
      expect(ShoppingLinks.allLinks(''), hasLength(5));
    });
  });

  // ---------------------------------------------------------------------------
  group('ShopLink value object', () {
    test('constructor sets all fields', () {
      const link = ShopLink(name: 'Test', url: 'https://example.com', icon: '🛒');
      expect(link.name, 'Test');
      expect(link.url, 'https://example.com');
      expect(link.icon, '🛒');
    });
  });
}
