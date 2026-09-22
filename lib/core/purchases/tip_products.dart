/// The three product identifiers, and the order they are offered in.
///
/// These are App Store Connect product ids. They are spelled literally here
/// because they are a wire format shared with a system outside this repository:
/// the same strings appear in App Store Connect, in the RevenueCat dashboard,
/// in a StoreKit receipt and in any support email about a charge. They are not
/// copy, they are never rendered, and translating one would break a purchase.
/// `test/l10n/no_hardcoded_strings_test.dart` carries the allowlist entry.
///
/// ## Why the app keeps its own ordered list at all
///
/// It would be shorter to render whatever the current offering returns, in
/// whatever order the dashboard happens to list it. Two things make that worse:
///
/// 1. **The labels are ARB copy, and copy has to be addressed by name.** The
///    store holds one display name per product in one language; this app ships
///    seven. So the screen needs a mapping from an id to a key, and a mapping
///    needs the ids.
/// 2. **Order becomes a dashboard setting nobody can see in a diff.** With this
///    list, small before medium before large is a fact in the repository. A
///    reordered offering cannot silently put the largest tip first, which is
///    exactly the sort of quiet change a purchase screen should not permit.
///
/// A product the offering returns that is not in this list is skipped rather
/// than rendered nameless. That is what makes the Monthly and Yearly products
/// sitting unused in the RevenueCat dashboard a non-event here.
library;

/// The smallest tip.
const String tipSmallId = 'app.vitomy.tip.small';

/// The middle tip.
const String tipMediumId = 'app.vitomy.tip.medium';

/// The largest tip.
const String tipLargeId = 'app.vitomy.tip.large';

/// Every tip the app offers, in the order it offers them.
const List<String> tipProductIds = <String>[
  tipSmallId,
  tipMediumId,
  tipLargeId,
];
