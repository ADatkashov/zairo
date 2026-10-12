import 'package:business_admin/features/loyalty/presentation/screens/loyalty_screen.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http.dart';
import '../../helpers/pump_app.dart';

Map<String, Object?> _provider(String id, String name) =>
    {'id': id, 'ownerUserId': 'o1', 'name': name, 'vertical': 'beauty', 'status': 'ACTIVE'};

FakeHttp _backend({List<Map<String, Object?>>? providers}) {
  final http = FakeHttp();
  http.reply('GET', '/users/o1/providers', providers ?? [_provider('p1', 'Glow Salon')]);
  for (final id in ['p1', 'p2']) {
    final base = '/business/$id/loyalty';
    http.reply('GET', '$base/overview', {
      'totalMembers': 100,
      'activeMembers': 60,
      'totalPointsIssued': 50000,
      'totalPointsRedeemed': 20000,
      'outstandingPointsLiability': 30000,
      'rewardsRedeemed': 40,
    });
    http.reply('GET', '$base/tiers', <Object?>[]);
    http.reply('GET', '$base/milestones', <Object?>[]);
    http.reply('GET', '$base/rewards', <Object?>[]);
    http.reply('GET', '$base/birthdays', <Object?>[]);
  }
  return http;
}

Future<void> _open(WidgetTester tester, FakeHttp http) async {
  useTallScreen(tester, size: const Size(1800, 3000));
  await tester.pumpWidget(appOn(http, const LoyaltyScreen(ownerUserId: 'o1')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('someone with no business is told to create one first', (tester) async {
    await _open(tester, _backend(providers: []));

    expect(find.text(en.loyaltyNoBusinesses), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets('businesses that fail to load show an error and retrying works', (tester) async {
    final http = _backend();
    http.fail('GET', '/users/o1/providers', 500);
    await _open(tester, http);
    expect(find.text(en.errorBusinessesLoadFailed), findsOneWidget);

    http.reply('GET', '/users/o1/providers', [_provider('p1', 'Glow Salon')]);
    await tester.tap(find.descendant(of: find.byType(FactoryErrorState), matching: find.byType(FactoryButton)));
    await tester.pumpAndSettle();

    expect(find.byType(TabBar), findsOneWidget);
  });

  testWidgets('has a tab for every part of the programme and opens on the overview', (tester) async {
    final http = _backend();
    await _open(tester, http);

    for (final label in [
      en.loyaltyTabOverview,
      en.loyaltyTabSettings,
      en.loyaltyTabRewards,
      en.loyaltyTabCustomers,
      en.loyaltyTabBirthdays,
      en.loyaltyTabRedemptions,
      en.loyaltyTabMilestones,
      en.loyaltyTabTiers,
    ]) {
      expect(find.descendant(of: find.byType(TabBar), matching: find.text(label)), findsOneWidget, reason: label);
    }
    expect(find.text(en.loyaltyScreenTitle), findsOneWidget);
    expect(http.calls('GET', '/business/p1/loyalty/overview'), hasLength(1));
  });

  testWidgets('opening a tab loads that part for the chosen business', (tester) async {
    final http = _backend();
    await _open(tester, http);

    await tester.tap(find.descendant(of: find.byType(TabBar), matching: find.text(en.loyaltyTabTiers)));
    await tester.pumpAndSettle();
    expect(http.calls('GET', '/business/p1/loyalty/tiers'), hasLength(1));

    await tester.tap(find.descendant(of: find.byType(TabBar), matching: find.text(en.loyaltyTabBirthdays)));
    await tester.pumpAndSettle();
    expect(http.calls('GET', '/business/p1/loyalty/birthdays'), hasLength(1));
  });

  testWidgets('one business shows no picker', (tester) async {
    await _open(tester, _backend());

    expect(find.byType(FactoryChip), findsNothing);
  });

  testWidgets('several businesses show a chip each; picking another loads its programme', (tester) async {
    final http = _backend(providers: [_provider('p1', 'Glow Salon'), _provider('p2', 'Auto Pro')]);
    await _open(tester, http);
    expect(find.byType(FactoryChip), findsNWidgets(2));
    expect(http.calls('GET', '/business/p2/loyalty/overview'), isEmpty);

    await tester.tap(find.text('Glow Salon')); // already chosen: nothing new loads
    await tester.pumpAndSettle();
    expect(http.calls('GET', '/business/p1/loyalty/overview'), hasLength(1));

    await tester.tap(find.text('Auto Pro'));
    await tester.pumpAndSettle();
    expect(http.calls('GET', '/business/p2/loyalty/overview'), hasLength(1));
  });
}
