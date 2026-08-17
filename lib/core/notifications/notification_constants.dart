/// The values more than one layer of the notification stack needs, and nothing
/// else (Phase 7, NOTIF-01/02, 07-UI-SPEC DECIDED-13/14/18).
///
/// Pure: imports nothing at all. The pure plan, the timezone adapter, the
/// platform adapter and the tap router all read from here, so none of them has
/// to import another and none of them can hold a second opinion about a channel
/// id or a payload token.
library;

/// The Android notification channel id.
///
/// Deliberately NOT re-versioned to change the channel's language. Android's
/// `createNotificationChannel` UPDATES the name and description of an existing
/// id, so the localized name is re-applied at startup and on every language
/// change with the id untouched (07-UI-SPEC DECIDED-14, which corrects
/// 07-RESEARCH Pitfall 8). Versioning it would create a SECOND channel in the
/// operating system's own settings list and orphan the customizations the user
/// made on the first — the exact harm the pitfall warns about, caused by
/// following its remedy. The `_v1` suffix is an escape hatch for a genuine
/// behavioural change (a different importance floor), never for copy.
const doseChannelId = 'doses_v1';

/// The one payload token any notification of this app ever carries.
///
/// It names the destination and nothing else: no dose time, no supplement, no
/// day. There is exactly one, which is what lets the check on the way back in be
/// a single equality (see [isKnownNotificationPayload]) and what keeps a dose
/// time out of a string the operating system persists (DECIDED-13).
const doseTapPayload = 'today';

/// Index of the Сьогодні destination in the app shell (0 Стек / 1 Сьогодні /
/// 2 Календар).
const todayTabIndex = 1;

/// Whether [payload] is the app's own known routing token.
///
/// A WHITELIST, not a parse, and the distinction is a security control. The
/// operating system persists a payload across app updates and can replay it
/// back into a build that never wrote it, so it is untrusted local input in
/// exactly the sense the stored locale tag already is — `locale_controller.dart`
/// takes the same stance for the same reason. An older build's payload, a null
/// or any unknown string answers false and produces no navigation at all,
/// rather than being pattern-matched into a route.
bool isKnownNotificationPayload(String? payload) => payload == doseTapPayload;

/// The maximum number of pending requests the app will ever hold.
///
/// iOS keeps at most 64 pending local notification requests per app and the two
/// credible descriptions of what it evicts past that ceiling disagree with each
/// other (07-RESEARCH R-11, assumption A2). Enforcing 60 inside the PURE plan —
/// never in the platform adapter — means the app never finds out which
/// description is right: no platform behaviour is load-bearing, whatever the
/// size of the user's stack.
const notificationBudget = 60;

/// How far ahead individually-scheduled reminders are armed, in days.
///
/// Binds together with [notificationBudget], whichever comes first. The cost is
/// stated honestly in the spec: for a cycling stack the budget usually binds
/// well inside this window, so reminders lapse if the app is never opened.
const notificationHorizonDays = 30;
