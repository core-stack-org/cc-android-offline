import 'package:flutter_test/flutter_test.dart';
import 'package:nrmflutter/utils/layers_config.dart';

void main() {
  test('selected plan generates only its plan-specific layers', () async {
    final layers = await LayersConfig.getLayers(
      'Dumka',
      'Kathikund',
      blockId: '741',
      planId: 42,
    );

    final planLayers = layers.where(
      (layer) => layer['name']?.endsWith('_42') == true,
    );

    expect(planLayers, hasLength(8));
    expect(
      planLayers.every(
        (layer) => layer['geoserverPath']?.contains('_42_') == true,
      ),
      isTrue,
    );
    expect(layers.where((layer) => layer['name']?.endsWith('_43') == true),
        isEmpty);
  });
}
