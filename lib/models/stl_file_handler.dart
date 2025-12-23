import 'dart:io';
import 'package:urdf_parser/urdf_parser.dart' as urdf;
import 'package:three_dart/three_dart.dart' as three;
import 'package:vector_math/vector_math.dart';
import 'mesh_3d.dart';

class STLFileHandler {
  /// Load STL file using urdf_parser and convert to Mesh3D
  static Future<Mesh3D?> loadSTLFile(String filePath) async {
    try {
      // Load STL using urdf_parser
      final stlObject = await urdf.STLLoader(null).loadAsync(filePath);

      // Extract vertices and indices from three.js Object3D
      List<Vector3> vertices = [];
      List<int> indices = [];
      List<Vector3> normals = [];

      // Traverse the loaded object to find geometry
      stlObject.traverse((child) {
        if (child is three.Mesh) {
          final geometry = child.geometry;

          if (geometry is three.BufferGeometry) {
            // Extract position attribute
            final positionAttr = geometry.attributes['position'];
            if (positionAttr is three.BufferAttribute) {
              final array = positionAttr.array;
              for (int i = 0; i < array.length; i += 3) {
                vertices.add(Vector3(
                  (array[i]).toDouble(),
                  (array[i + 1]).toDouble(),
                  (array[i + 2]).toDouble(),
                ));
              }
            }

            // Extract index if available
            final index = geometry.index;
            if (index != null) {
              final indexArray = index.array;
              for (int i = 0; i < indexArray.length; i++) {
                indices.add((indexArray[i]).toInt());
              }
            } else {
              // Generate indices if not present
              for (int i = 0; i < vertices.length; i++) {
                indices.add(i);
              }
            }

            // Extract normals if available
            final normalAttr = geometry.attributes['normal'];
            if (normalAttr is three.BufferAttribute) {
              final array = normalAttr.array;
              for (int i = 0; i < array.length; i += 3) {
                normals.add(Vector3(
                  (array[i]).toDouble(),
                  (array[i + 1]).toDouble(),
                  (array[i + 2]).toDouble(),
                ));
              }
            } else {
              // Calculate normals if not present
              normals = _calculateNormals(vertices, indices);
            }
          }
        }
      });

      if (vertices.isEmpty) {
        print('No vertices extracted from STL file');
        return null;
      }

      // Create Mesh3D object
      final mesh = Mesh3D(
        vertices: vertices,
        indices: indices,
        normals: normals,
      );

      // Normalize mesh
      mesh.normalize();

      return mesh;
    } catch (e) {
      print('Error loading STL file: $e');
      return null;
    }
  }

  /// Load STL from File object
  static Future<Mesh3D?> loadSTLFromFile(File file) async {
    return loadSTLFile(file.path);
  }

  /// Calculate normals from vertices and indices
  static List<Vector3> _calculateNormals(
      List<Vector3> vertices, List<int> indices) {
    List<Vector3> normals = List.filled(vertices.length, Vector3.zero());

    // Calculate face normals
    for (int i = 0; i < indices.length; i += 3) {
      final i0 = indices[i];
      final i1 = indices[i + 1];
      final i2 = indices[i + 2];

      final v0 = vertices[i0];
      final v1 = vertices[i1];
      final v2 = vertices[i2];

      final edge1 = v1 - v0;
      final edge2 = v2 - v0;
      final faceNormal = edge1.cross(edge2).normalized();

      // Add face normal to vertex normals
      normals[i0] += faceNormal;
      normals[i1] += faceNormal;
      normals[i2] += faceNormal;
    }

    // Normalize vertex normals
    for (int i = 0; i < normals.length; i++) {
      normals[i] = normals[i].normalized();
    }

    return normals;
  }

  /// Export path to CSV format for robot
  static Future<void> exportPathToCSV(
    List<Vector3> path,
    String outputPath, {
    String? name,
  }) async {
    try {
      final file = File(outputPath);

      final buffer = StringBuffer();
      buffer.writeln('Index,X,Y,Z');

      for (int i = 0; i < path.length; i++) {
        final point = path[i];
        buffer.writeln('$i,${point.x},${point.y},${point.z}');
      }

      await file.writeAsString(buffer.toString());
      print('Path exported to: $outputPath');
    } catch (e) {
      print('Error exporting path: $e');
    }
  }

  /// Export path to JSON format
  static Future<void> exportPathToJSON(
    List<Vector3> path,
    String outputPath, {
    String? name,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final file = File(outputPath);

      final points = path
          .asMap()
          .entries
          .map((e) => {
                'index': e.key,
                'x': e.value.x,
                'y': e.value.y,
                'z': e.value.z,
              })
          .toList();

      final json = {
        'name': name ?? 'Material Layering Path',
        'timestamp': DateTime.now().toIso8601String(),
        'pointCount': path.length,
        'metadata': metadata ?? {},
        'points': points,
      };

      await file.writeAsString(_jsonEncode(json));
      print('Path exported to: $outputPath');
    } catch (e) {
      print('Error exporting path: $e');
    }
  }

  /// Simple JSON encoder
  static String _jsonEncode(dynamic obj, [int indent = 0]) {
    final indentStr = '  ' * indent;
    final nextIndent = '  ' * (indent + 1);

    if (obj == null) {
      return 'null';
    } else if (obj is bool) {
      return obj.toString();
    } else if (obj is num) {
      return obj.toString();
    } else if (obj is String) {
      return '"${obj.replaceAll('"', '\\"')}"';
    } else if (obj is List) {
      if (obj.isEmpty) return '[]';
      final items =
          obj.map((e) => _jsonEncode(e, indent + 1)).join(',\n$nextIndent');
      return '[\n$nextIndent$items\n$indentStr]';
    } else if (obj is Map) {
      if (obj.isEmpty) return '{}';
      final items = obj.entries
          .map((e) => '"${e.key}": ${_jsonEncode(e.value, indent + 1)}')
          .join(',\n$nextIndent');
      return '{\n$nextIndent$items\n$indentStr}';
    }
    return obj.toString();
  }
}
