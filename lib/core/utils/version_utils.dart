/// Semantic version comparison utilities.
class VersionUtils {
  VersionUtils._();

  /// Returns true if [version] is strictly less than [minVersion].
  /// Both strings must be 'major.minor.patch' format. Extra components
  /// and non-numeric parts are treated as 0.
  static bool isLessThan(String version, String minVersion) {
    final v = _parse(version);
    final min = _parse(minVersion);
    for (int i = 0; i < 3; i++) {
      if (v[i] < min[i]) return true;
      if (v[i] > min[i]) return false;
    }
    return false; // equal → not less than
  }

  static List<int> _parse(String version) {
    final parts = version.split('.');
    return List.generate(
      3,
      (i) => i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0,
    );
  }
}
