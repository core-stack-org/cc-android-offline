String formatNameForGeoServer(String name) {
  if (name.isEmpty) return name;
  return name
      .replaceAll(RegExp(r'[()]'), '') // Remove all parentheses
      .replaceAll(RegExp(r'[-\s]+'), '_') // Replace dashes and spaces with "_"
      .replaceAll(RegExp(r'_+'), '_') // Collapse multiple underscores to one
      .replaceAll(RegExp(r'^_|_$'), '') // Remove leading/trailing underscores
      .toLowerCase();
}
