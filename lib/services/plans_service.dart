import 'dart:convert';

import 'login_service.dart';

class WatershedPlan {
  final int id;
  final String name;
  final String villageName;
  final String projectName;
  final String facilitatorName;
  final int? projectId;
  final Map<String, dynamic> details;

  const WatershedPlan({
    required this.id,
    required this.name,
    required this.villageName,
    required this.projectName,
    required this.facilitatorName,
    required this.projectId,
    required this.details,
  });

  bool get isTestPlan {
    final normalizedName = name.toLowerCase();
    return normalizedName.contains('test') || normalizedName.contains('demo');
  }

  factory WatershedPlan.fromJson(Map<String, dynamic> json) {
    return WatershedPlan(
      id: _asInt(json['id'] ?? json['plan_id'])!,
      name: (json['plan'] ?? json['name'] ?? '').toString(),
      villageName:
          (json['village_name'] ?? json['villageName'] ?? json['village'] ?? '')
              .toString(),
      projectName: (json['project_name'] ?? '').toString(),
      facilitatorName: (json['facilitator_name'] ?? '').toString(),
      projectId: _asInt(json['project'] ?? json['project_id']),
      details: json,
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}

WatershedPlan? findPlanForVillage(
  List<WatershedPlan> plans,
  String villageName,
) {
  final normalizedVillage = _normalizeVillageName(villageName);
  if (normalizedVillage.isEmpty) return null;

  final matches = plans
      .where(
        (plan) => _normalizeVillageName(plan.villageName) == normalizedVillage,
      )
      .toList();
  final regularMatches = matches.where((plan) => !plan.isTestPlan).toList();

  if (regularMatches.length == 1) return regularMatches.single;
  if (regularMatches.isEmpty && matches.length == 1) return matches.single;
  return null;
}

String _normalizeVillageName(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
}

bool planMatchesFacilitator(WatershedPlan plan, String userFullName) {
  return _normalizePersonName(plan.facilitatorName) ==
      _normalizePersonName(userFullName);
}

String _normalizePersonName(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

class PlansService {
  final LoginService _loginService;

  PlansService({LoginService? loginService})
      : _loginService = loginService ?? LoginService();

  Future<String> getUserRoleLabel() async {
    final user = await _loginService.getUserData();
    if (user == null) return 'Plan User';
    if (user['is_superadmin'] == true) return 'Superadmin';

    final groups = user['groups'];
    if (groups is List) {
      final names = groups
          .whereType<Map>()
          .map((group) => group['name']?.toString().trim())
          .whereType<String>()
          .where((name) => name.isNotEmpty)
          .map(
            (name) => name.toLowerCase() == 'app user' ? 'Plan User' : name,
          )
          .toList();
      if (names.isNotEmpty) return names.join(', ');
    }
    return 'Plan User';
  }

  Future<String?> getUserFullName() async {
    final user = await _loginService.getUserData();
    if (user == null) return null;

    final firstName = user['first_name']?.toString().trim() ?? '';
    final lastName = user['last_name']?.toString().trim() ?? '';
    if (firstName.isEmpty || lastName.isEmpty) return null;
    return '$firstName $lastName';
  }

  Future<List<WatershedPlan>> fetchPlans({
    required String tehsilId,
  }) async {
    final user = await _loginService.getUserData();
    if (user == null) {
      throw const PlansException('Your session is no longer available.');
    }

    final plans = user['is_superadmin'] == true
        ? await _fetchPlanList('watershed/plans/?tehsil=$tehsilId')
        : await _fetchAssignedProjectPlans(user);

    final uniquePlans = <int, WatershedPlan>{
      for (final plan in plans) plan.id: plan,
    }.values.toList();
    uniquePlans.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return uniquePlans;
  }

  Future<Map<String, dynamic>> fetchPlanDetails(WatershedPlan plan) async {
    if (plan.projectId == null) return plan.details;

    final response = await _loginService.makeAuthenticatedRequest(
      'projects/${plan.projectId}/watershed/plans/${plan.id}/',
    );
    if (response == null) {
      throw const PlansException('Could not connect to the server.');
    }
    if (response.statusCode != 200) {
      throw PlansException(_errorMessage(response.body));
    }

    final data = jsonDecode(response.body);
    return data is Map<String, dynamic> ? data : plan.details;
  }

  Future<List<WatershedPlan>> _fetchAssignedProjectPlans(
    Map<String, dynamic> user,
  ) async {
    final projects = user['project_details'];
    if (projects is! List || projects.isEmpty) {
      return [];
    }

    final projectIds = projects
        .whereType<Map>()
        .map(
          (project) => WatershedPlan._asInt(
            project['id'] ?? project['project_id'] ?? project['project'],
          ),
        )
        .whereType<int>()
        .toSet();

    if (projectIds.isEmpty) {
      throw const PlansException(
        'Assigned projects do not include project IDs.',
      );
    }

    final planLists = await Future.wait(
      projectIds.map(
        (id) => _fetchPlanList('projects/$id/watershed/plans/'),
      ),
    );
    return planLists.expand((plans) => plans).toList();
  }

  Future<List<WatershedPlan>> _fetchPlanList(String endpoint) async {
    final response = await _loginService.makeAuthenticatedRequest(endpoint);
    if (response == null) {
      throw const PlansException('Could not connect to the server.');
    }
    if (response.statusCode != 200) {
      throw PlansException(_errorMessage(response.body));
    }

    final decoded = jsonDecode(response.body);
    final data = decoded is List
        ? decoded
        : decoded is Map<String, dynamic> && decoded['results'] is List
            ? decoded['results'] as List
            : const [];

    return data
        .whereType<Map>()
        .map((plan) => Map<String, dynamic>.from(plan))
        .where(
          (plan) => WatershedPlan._asInt(plan['id'] ?? plan['plan_id']) != null,
        )
        .map(WatershedPlan.fromJson)
        .toList();
  }

  String _errorMessage(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        return (data['detail'] ?? data['message'] ?? 'Could not load plans.')
            .toString();
      }
    } catch (_) {}
    return 'Could not load plans.';
  }
}

class PlansException implements Exception {
  final String message;

  const PlansException(this.message);

  @override
  String toString() => message;
}
