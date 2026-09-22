/// A [PurchaseGateway] that records what it was asked and answers on command.
///
/// A shared file rather than a private class in each suite, mirroring
/// `test/notifications/recording_scheduler.dart` — the provider suite and the
/// screen suite need the same recorder, and two copies would drift the day the
/// seam grows a method.
///
/// It counts calls as well as capturing them. The count is what proves the
/// ordering guarantee this layer exists for: "the SDK was never asked for an
/// offering before configure completed" is a claim about a call that did NOT
/// happen, and only a counter can hold it.
library;

import 'package:vitomy/core/purchases/purchase_gateway.dart';

class RecordingPurchaseGateway extends PurchaseGateway {
  RecordingPurchaseGateway({
    this.offered = const <TipProduct>[],
    this.result = TipPurchaseResult.bought,
    this.throwOnConfigure = false,
    this.throwOnTips = false,
  });

  /// What [tips] answers when it is allowed to answer at all.
  List<TipProduct> offered;

  /// What [buy] answers.
  TipPurchaseResult result;

  /// Makes [configure] throw, modelling a device with no network on its first
  /// ever launch.
  bool throwOnConfigure;

  /// Makes [tips] throw, modelling an offering fetch that fails after a
  /// configure that succeeded.
  bool throwOnTips;

  int configureCalls = 0;
  int tipsCalls = 0;

  /// Every product id [buy] was asked for, in order.
  final List<String> bought = <String>[];

  @override
  Future<void> configure() async {
    configureCalls++;
    if (throwOnConfigure) throw StateError('no network');
  }

  @override
  Future<List<TipProduct>> tips() async {
    tipsCalls++;
    if (throwOnTips) throw StateError('offerings unreachable');
    return offered;
  }

  @override
  Future<TipPurchaseResult> buy(String productId) async {
    bought.add(productId);
    return result;
  }
}
