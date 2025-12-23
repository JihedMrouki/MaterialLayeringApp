import 'dart:math';
import 'package:vector_math/vector_math.dart';
import 'mesh_3d.dart';

class LayeringAlgorithm {
  final Mesh3D mesh;

  LayeringAlgorithm({required this.mesh});

  /// Generate complete path for material layering
  List<Vector3> generatePath({
    required double standoffDistance,
    required int dotCount,
    required double layerHeight,
    bool connectLayers = true,
  }) {
    List<Vector3> allPoints = [];

    final bbox = mesh.getBoundingBox();
    final minZ = bbox['min']!.z;
    final maxZ = bbox['max']!.z;
    final zRange = maxZ - minZ;

    if (zRange <= 0) return [];

    final layerCount = max(1, (zRange / layerHeight).ceil());
    final pointsPerLayer = max(1, (dotCount / layerCount).ceil());

    for (int layer = 0; layer < layerCount; layer++) {
      final z = minZ + (layer * zRange / layerCount);

      // Get cross-section at this height
      List<Vector3> crossSection = mesh.sliceAtHeight(z);

      if (crossSection.isEmpty) continue;

      // Generate perimeter points with offset
      List<Vector3> layerPoints = _generatePerimeterPoints(
        crossSection,
        pointsPerLayer,
        standoffDistance,
      );

      // Order points for continuous path
      layerPoints = _orderPathOptimal(layerPoints);

      allPoints.addAll(layerPoints);
    }

    // Connect layers if enabled
    if (connectLayers && allPoints.length > 2) {
      allPoints = _connectLayers(allPoints, layerCount, pointsPerLayer);
    }

    return allPoints;
  }

  /// Generate N points around the perimeter with offset
  List<Vector3> _generatePerimeterPoints(
    List<Vector3> crossSection,
    int pointCount,
    double offset,
  ) {
    if (crossSection.isEmpty) return [];

    // Calculate centroid
    Vector3 centroid = Vector3.zero();
    for (var point in crossSection) {
      centroid += point;
    }
    centroid /= crossSection.length.toDouble();

    // Generate points in circular pattern around centroid
    List<Vector3> perimeterPoints = [];
    final angleStep = (2 * pi) / pointCount;

    // Calculate average radius from centroid
    double avgRadius = 0;
    for (var point in crossSection) {
      final dx = point.x - centroid.x;
      final dy = point.y - centroid.y;
      avgRadius += sqrt(dx * dx + dy * dy);
    }
    avgRadius /= crossSection.length;
    avgRadius += offset; // Add standoff distance

    for (int i = 0; i < pointCount; i++) {
      final angle = i * angleStep;
      final x = centroid.x + avgRadius * cos(angle);
      final y = centroid.y + avgRadius * sin(angle);

      perimeterPoints.add(Vector3(x, y, crossSection.first.z));
    }

    return perimeterPoints;
  }

  /// Order points for optimal path (greedy nearest neighbor)
  List<Vector3> _orderPathOptimal(List<Vector3> points) {
    if (points.length <= 1) return points;

    List<Vector3> ordered = [];
    List<int> remaining = List.generate(points.length, (i) => i);

    // Start from first point
    ordered.add(points[0]);
    remaining.removeAt(0);

    while (remaining.isNotEmpty) {
      final lastPoint = ordered.last;
      double minDistance = double.infinity;
      int nearestIdx = 0;

      for (int i = 0; i < remaining.length; i++) {
        final distance = (points[remaining[i]] - lastPoint).length;
        if (distance < minDistance) {
          minDistance = distance;
          nearestIdx = i;
        }
      }

      final nextIdx = remaining[nearestIdx];
      ordered.add(points[nextIdx]);
      remaining.removeAt(nearestIdx);
    }

    return ordered;
  }

  /// Connect layers smoothly
  List<Vector3> _connectLayers(
    List<Vector3> points,
    int layerCount,
    int pointsPerLayer,
  ) {
    List<Vector3> connected = [];

    for (int layer = 0; layer < layerCount; layer++) {
      final startIdx = layer * pointsPerLayer;
      final endIdx = min((layer + 1) * pointsPerLayer, points.length);

      for (int i = startIdx; i < endIdx; i++) {
        connected.add(points[i]);
      }

      // Add connection point to next layer if available
      if (layer < layerCount - 1 && endIdx < points.length) {
        final lastPoint = points[endIdx - 1];
        final nextFirstPoint = points[endIdx];

        // Intermediate connection point
        final connectionPoint = Vector3(
          (lastPoint.x + nextFirstPoint.x) / 2,
          (lastPoint.y + nextFirstPoint.y) / 2,
          (lastPoint.z + nextFirstPoint.z) / 2,
        );

        connected.add(connectionPoint);
      }
    }

    return connected;
  }

  /// Calculate total path length
  double calculatePathLength(List<Vector3> path) {
    if (path.length < 2) return 0;

    double totalLength = 0;
    for (int i = 0; i < path.length - 1; i++) {
      totalLength += (path[i + 1] - path[i]).length;
    }
    return totalLength;
  }

  /// Estimate time for robot to complete path
  double estimateTime(List<Vector3> path, double speed) {
    if (speed <= 0) return 0;
    return calculatePathLength(path) / speed;
  }
}
