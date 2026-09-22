/// The seam's own contract, proved by driving it rather than by reading it.
///
/// Two of these assertions look trivial and are not. The no-op gateway is what
/// every test in this repository gets by default and what production gets if
/// the override in `main()` is ever dropped, so what it does on a failed
/// override IS the behaviour of a shipped build with no purchases wired. It
/// must be indistinguishable from "the store has nothing to sell", never from
/// "the tip went through".
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:vitomy/core/purchases/purchase_gateway.dart';

void main() {
  group('the no-op gateway', () {
    test('configures without throwing', () async {
      const gateway = NoopPurchaseGateway();
      await expectLater(gateway.configure(), completes);
    });

    test('offers nothing', () async {
      const gateway = NoopPurchaseGateway();
      expect(await gateway.tips(), isEmpty);
    });

    test('reports a purchase as FAILED, never as bought', () async {
      const gateway = NoopPurchaseGateway();
      expect(
        await gateway.buy('app.vitomy.tip.small'),
        TipPurchaseResult.failed,
        reason: 'a forgotten override in main() must not look like a working '
            'purchase. The notification seam makes the opposite choice for the '
            'opposite reason: a silent no-op there costs a reminder, while a '
            'silent success here would tell a user their money arrived',
      );
    });

    test('reports a purchase as failed rather than cancelled', () async {
      const gateway = NoopPurchaseGateway();
      expect(
        await gateway.buy('app.vitomy.tip.large'),
        isNot(TipPurchaseResult.cancelled),
        reason: 'cancelled is the ONE result the screen renders nothing for, '
            'so a no-op returning it would leave a tapped button with no '
            'feedback of any kind',
      );
    });
  });

  group('the value types', () {
    test('a tip carries the store\'s own formatted price, not a number', () {
      const tip = TipProduct(id: 'app.vitomy.tip.medium', priceString: r'$4.99');
      expect(tip.priceString, isA<String>());
      expect(
        tip.priceString,
        isNot(matches(RegExp(r'^\d'))),
        reason: 'the price arrives already localized and already '
            'currency-correct from StoreProduct.priceString. A double here '
            'would mean the app had started formatting money, which it must '
            'never do: the store knows the user\'s storefront and the app does '
            'not',
      );
    });

    test('two tips with the same id and price are equal', () {
      const a = TipProduct(id: 'app.vitomy.tip.small', priceString: r'$2.99');
      const b = TipProduct(id: 'app.vitomy.tip.small', priceString: r'$2.99');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a price change makes a tip unequal to its old self', () {
      const before = TipProduct(id: 'app.vitomy.tip.small', priceString: r'$2.99');
      const after = TipProduct(id: 'app.vitomy.tip.small', priceString: r'$3.49');
      expect(
        before,
        isNot(after),
        reason: 'Apple can move a storefront price under the app. Equality '
            'that ignored the price would let a FutureProvider hand the screen '
            'a stale one and never rebuild',
      );
    });

    test('every result the screen must distinguish exists', () {
      expect(TipPurchaseResult.values, hasLength(3));
      expect(
        TipPurchaseResult.values,
        containsAll(<TipPurchaseResult>[
          TipPurchaseResult.bought,
          TipPurchaseResult.cancelled,
          TipPurchaseResult.failed,
        ]),
      );
    });
  });
}
