import 'package:vector_math/vector_math.dart';

class Mesh3D {
  final List<Vector3> vertices;
  final List<int> indices;
  final List<Vector3> normals;

  Vector3 center;
  double scale;

  Mesh3D({
    required this.vertices,
    required this.indices,
    required this.normals,
    Vector3? center,
    this.scale = 1.0,
  }) : center = center ?? Vector3.zero();

  /// Calculate mesh bounding box
  Map<String, Vector3> getBoundingBox() {
    if (vertices.isEmpty) {
      return {'min': Vector3.zero(), 'max': Vector3.zero()};
    }

    Vector3 min = vertices[0].clone();
    Vector3 max = vertices[0].clone();

    for (var vertex in vertices) {
      if (vertex.x < min.x) min.x = vertex.x;
      if (vertex.y < min.y) min.y = vertex.y;
      if (vertex.z < min.z) min.z = vertex.z;

      if (vertex.x > max.x) max.x = vertex.x;
      if (vertex.y > max.y) max.y = vertex.y;
      if (vertex.z > max.z) max.z = vertex.z;
    }

    return {'min': min, 'max': max};
  }

  /// Calculate mesh center
  void calculateCenter() {
    if (vertices.isEmpty) return;

    Vector3 sum = Vector3.zero();
    for (var vertex in vertices) {
      sum += vertex;
    }
    center = sum / vertices.length.toDouble();
  }

  /// Normalize mesh to unit size
  void normalize() {
    calculateCenter();

    final bbox = getBoundingBox();
    final min = bbox['min']!;
    final max = bbox['max']!;

    final size = (max - min).length;
    if (size > 0) {
      scale = 1.0 / size;

      for (int i = 0; i < vertices.length; i++) {
        vertices[i] = (vertices[i] - center) * scale;
      }
      center = Vector3.zero();
    }
  }

  /// Get surface points at specific height (Z-level)
  List<Vector3> sliceAtHeight(double z) {
    List<Vector3> crossSection = [];

    for (int i = 0; i < indices.length; i += 3) {
      final v0 = vertices[indices[i]];
      final v1 = vertices[indices[i + 1]];
      final v2 = vertices[indices[i + 2]];

      // Check if triangle intersects the plane at height z
      final minZ = [v0.z, v1.z, v2.z].reduce((a, b) => a < b ? a : b);
      final maxZ = [v0.z, v1.z, v2.z].reduce((a, b) => a > b ? a : b);

      if (minZ <= z && z <= maxZ) {
        // Simple intersection point calculation
        final point = Vector3(
          (v0.x + v1.x + v2.x) / 3,
          (v0.y + v1.y + v2.y) / 3,
          z,
        );
        crossSection.add(point);
      }
    }

    return crossSection;
  }
}
