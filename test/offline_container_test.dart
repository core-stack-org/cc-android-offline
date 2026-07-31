import 'package:flutter_test/flutter_test.dart';
import 'package:nrmflutter/container_flow/container_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('selected plan identity survives container serialization', () {
    final container = OfflineContainer(
      name: 'Belpahari',
      state: 'Jharkhand',
      district: 'Dumka',
      block: 'Kathikund',
      planId: 42,
      planName: 'Belpahari Watershed Plan',
      projectId: 7,
      projectName: 'Dumka Project',
      createdAt: DateTime.utc(2026, 7, 30),
      downloadedAt: DateTime.utc(2026, 7, 31),
      latitude: 24.1,
      longitude: 87.2,
    );

    final restored = OfflineContainer.fromJson(container.toJson());

    expect(restored.planId, 42);
    expect(restored.planName, 'Belpahari Watershed Plan');
    expect(restored.projectId, 7);
    expect(restored.projectName, 'Dumka Project');
    expect(restored.downloadedAt, DateTime.utc(2026, 7, 31));
  });

  test('successful download records its completion date', () async {
    SharedPreferences.setMockInitialValues({});
    final container = OfflineContainer(
      name: 'Belpahari',
      state: 'Jharkhand',
      district: 'Dumka',
      block: 'Kathikund',
      planId: 42,
      planName: 'Belpahari Watershed Plan',
      createdAt: DateTime.utc(2026, 7, 30),
      latitude: 24.1,
      longitude: 87.2,
    );

    await ContainerManager.saveContainer(container);
    await ContainerManager.updateContainerDownloadStatus(container.name, true);

    final restored = await ContainerManager.getContainer(container.name);
    expect(restored?.downloadedAt, isNotNull);
  });
}
