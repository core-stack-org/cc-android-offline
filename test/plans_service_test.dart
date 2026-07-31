import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nrmflutter/services/login_service.dart';
import 'package:nrmflutter/services/plans_service.dart';

void main() {
  test('superadmins load tehsil plans and sort test plans independently',
      () async {
    final loginService = _FakeLoginService(
      user: {'is_superadmin': true},
      responses: {
        'watershed/plans/?tehsil=741': http.Response(
          '''
          [
            {"id": 2, "plan": "Test Plan", "project": 5},
            {"id": 1, "plan": "Alpha Plan", "project": 5}
          ]
          ''',
          200,
        ),
      },
    );

    final plans = await PlansService(loginService: loginService)
        .fetchPlans(tehsilId: '741');

    expect(plans.map((plan) => plan.name), ['Alpha Plan', 'Test Plan']);
    expect(plans.first.isTestPlan, isFalse);
    expect(plans.last.isTestPlan, isTrue);
  });

  test('assigned users load and deduplicate plans from their projects',
      () async {
    final loginService = _FakeLoginService(
      user: {
        'is_superadmin': false,
        'project_details': [
          {'project_id': 10},
          {'id': 20},
        ],
      },
      responses: {
        'projects/10/watershed/plans/': http.Response(
          '[{"id": 1, "plan": "Plan A", "project": 10}]',
          200,
        ),
        'projects/20/watershed/plans/': http.Response(
          '''
          [
            {"id": 1, "plan": "Plan A", "project": 10},
            {"id": 2, "plan": "Plan B", "project": 20}
          ]
          ''',
          200,
        ),
      },
    );

    final plans = await PlansService(loginService: loginService)
        .fetchPlans(tehsilId: '741');

    expect(plans.map((plan) => plan.id), [1, 2]);
  });

  test('finds a unique regular plan for a normalized village name', () {
    final plans = [
      WatershedPlan.fromJson({
        'id': 1,
        'plan': 'Village Plan',
        'village': 'Amra-Kamat',
      }),
      WatershedPlan.fromJson({
        'id': 2,
        'plan': 'Demo Plan',
        'village_name': 'Amra Kamat',
      }),
    ];

    expect(findPlanForVillage(plans, 'amra_kamat')?.id, 1);
  });

  test('does not guess when multiple regular plans match a village', () {
    final plans = [
      WatershedPlan.fromJson({
        'id': 1,
        'plan': 'Plan One',
        'villageName': 'Belpahari',
      }),
      WatershedPlan.fromJson({
        'id': 2,
        'plan': 'Plan Two',
        'village_name': 'Belpahari',
      }),
    ];

    expect(findPlanForVillage(plans, 'Belpahari'), isNull);
  });

  test('uses superadmin flag or group names for the role label', () async {
    final superadminService = PlansService(
      loginService: _FakeLoginService(
        user: {'is_superadmin': true},
        responses: const {},
      ),
    );
    final adminService = PlansService(
      loginService: _FakeLoginService(
        user: {
          'groups': [
            {'name': 'Organization Admin'},
          ],
        },
        responses: const {},
      ),
    );
    final planUserService = PlansService(
      loginService: _FakeLoginService(
        user: {
          'groups': [
            {'name': 'App User'},
          ],
        },
        responses: const {},
      ),
    );

    expect(await superadminService.getUserRoleLabel(), 'Superadmin');
    expect(await adminService.getUserRoleLabel(), 'Organization Admin');
    expect(await planUserService.getUserRoleLabel(), 'Plan User');
  });

  test('matches plans to the logged-in user facilitator name', () async {
    final service = PlansService(
      loginService: _FakeLoginService(
        user: {
          'first_name': 'Ankit',
          'last_name': 'Kumar',
        },
        responses: const {},
      ),
    );
    final plan = WatershedPlan.fromJson({
      'id': 1,
      'plan': 'Village Plan',
      'facilitator_name': '  ankit   kumar ',
    });

    final fullName = await service.getUserFullName();

    expect(fullName, 'Ankit Kumar');
    expect(planMatchesFacilitator(plan, fullName!), isTrue);
  });
}

class _FakeLoginService extends LoginService {
  final Map<String, dynamic> user;
  final Map<String, http.Response> responses;

  _FakeLoginService({required this.user, required this.responses});

  @override
  Future<Map<String, dynamic>?> getUserData() async => user;

  @override
  Future<http.Response?> makeAuthenticatedRequest(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    return responses[endpoint];
  }
}
