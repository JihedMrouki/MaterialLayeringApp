import 'package:dot_matrix/widgets/3d_viewer.dart';
import 'package:dot_matrix/widgets/control_panel.dart';
import 'package:dot_matrix/models/layering_algorithm.dart';
import 'package:dot_matrix/models/mesh_3d.dart';
import 'package:dot_matrix/models/stl_file_handler.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_math/vector_math.dart' as vm;

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Mesh3D? loadedMesh;
  LayeringAlgorithm? algorithm;
  List<vm.Vector3> generatedPath = [];

  // Parameters
  double standoffDistance = 0.3;
  int dotCount = 2600;
  double sphereRadius = 0.1;
  double layerHeight = 0.2;

  bool isLoading = false;
  String statusMessage = 'Ready';

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isWideScreen ? 'Material Layering System' : 'Layering',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            if (isWideScreen)
              Text(
                statusMessage,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                loadedMesh != null ? '✓ Model' : 'No Model',
                style: TextStyle(
                  fontSize: 12,
                  color: loadedMesh != null
                      ? const Color(0xFF00D9FF)
                      : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: isWideScreen
          ? Row(
              children: [
                // 3D Viewer (70%)
                Expanded(
                  flex: 7,
                  child: ThreeDViewer(
                    mesh: loadedMesh,
                    path: generatedPath,
                    sphereRadius: sphereRadius,
                    showMesh: loadedMesh != null,
                    showPath: generatedPath.isNotEmpty,
                    showDots: generatedPath.isNotEmpty,
                  ),
                ),
                // Divider
                VerticalDivider(
                  width: 1,
                  color: Colors.grey[800],
                ),
                // Control Panel (30%)
                Expanded(
                  flex: 3,
                  child: ControlPanel(
                    key: const ValueKey('desktop_control_panel'),
                    onStandoffChanged: (value) {
                      setState(() => standoffDistance = value);
                      _updatePath();
                    },
                    onDotCountChanged: (value) {
                      setState(() => dotCount = value);
                      _updatePath();
                    },
                    onSphereRadiusChanged: (value) {
                      setState(() => sphereRadius = value);
                    },
                    onLayerHeightChanged: (value) {
                      setState(() => layerHeight = value);
                      _updatePath();
                    },
                    onLoadSTL: _loadSTLFile,
                    onExport: _exportPath,
                    onRegeneratePath: _updatePath,
                    currentDotCount: generatedPath.length,
                    currentPathLength:
                        algorithm?.calculatePathLength(generatedPath) ?? 0.0,
                    isLoading: isLoading,
                  ),
                ),
              ],
            )
          : Column(
              children: [
                // Status message for mobile
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.grey[900],
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          statusMessage,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // 3D Viewer (50% on mobile)
                Expanded(
                  flex: 1,
                  child: ThreeDViewer(
                    key: const ValueKey('mobile_3d_viewer'),
                    mesh: loadedMesh,
                    path: generatedPath,
                    sphereRadius: sphereRadius,
                    showMesh: loadedMesh != null,
                    showPath: generatedPath.isNotEmpty,
                    showDots: generatedPath.isNotEmpty,
                  ),
                ),
                // Divider
                Divider(
                  height: 1,
                  color: Colors.grey[800],
                ),
                // Control Panel (50% on mobile, scrollable)
                Expanded(
                  flex: 1,
                  child: ControlPanel(
                    key: const ValueKey('mobile_control_panel'),
                    onStandoffChanged: (value) {
                      setState(() => standoffDistance = value);
                      _updatePath();
                    },
                    onDotCountChanged: (value) {
                      setState(() => dotCount = value);
                      _updatePath();
                    },
                    onSphereRadiusChanged: (value) {
                      setState(() => sphereRadius = value);
                    },
                    onLayerHeightChanged: (value) {
                      setState(() => layerHeight = value);
                      _updatePath();
                    },
                    onLoadSTL: _loadSTLFile,
                    onExport: _exportPath,
                    onRegeneratePath: _updatePath,
                    currentDotCount: generatedPath.length,
                    currentPathLength:
                        algorithm?.calculatePathLength(generatedPath) ?? 0.0,
                    isLoading: isLoading,
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _loadSTLFile() async {
    try {
      setState(() {
        isLoading = true;
        statusMessage = 'Loading STL file...';
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['stl', 'STL'],
      );

      if (result == null) {
        setState(() {
          isLoading = false;
          statusMessage = 'Cancelled';
        });
        return;
      }

      final filePath = result.files.single.path!;

      // Load STL using urdf_parser
      final mesh = await STLFileHandler.loadSTLFile(filePath);

      if (mesh == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load STL file'),
              backgroundColor: Color(0xFFFF0000),
            ),
          );
        }
        setState(() {
          isLoading = false;
          statusMessage = 'Error loading file';
        });
        return;
      }

      setState(() {
        loadedMesh = mesh;
        algorithm = LayeringAlgorithm(mesh: mesh);
        isLoading = false;
        statusMessage = 'Model loaded: ${mesh.vertices.length} vertices';
      });

      // Generate initial path
      _updatePath();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Loaded: ${mesh.vertices.length} vertices',
            ),
            backgroundColor: const Color(0xFF00D9FF),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error loading STL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFFF0000),
          ),
        );
      }
      setState(() {
        isLoading = false;
        statusMessage = 'Error: $e';
      });
    }
  }

  void _updatePath() {
    if (algorithm == null) return;

    try {
      setState(() => statusMessage = 'Generating path...');

      final path = algorithm!.generatePath(
        standoffDistance: standoffDistance,
        dotCount: dotCount,
        layerHeight: layerHeight,
        connectLayers: true,
      );

      final pathLength = algorithm!.calculatePathLength(path);

      setState(() {
        generatedPath = path;
        statusMessage =
            'Path generated: ${path.length} points, ${pathLength.toStringAsFixed(2)} units';
      });
    } catch (e) {
      print('Error generating path: $e');
      setState(() => statusMessage = 'Error generating path');
    }
  }

  Future<void> _exportPath() async {
    if (generatedPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No path to export. Generate a path first.'),
          backgroundColor: Color(0xFFFF0000),
        ),
      );
      return;
    }

    try {
      final directory = await getDownloadsDirectory();
      if (directory == null) {
        throw Exception('Cannot access downloads directory');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final csvPath = '${directory.path}/layering_path_$timestamp.csv';
      final jsonPath = '${directory.path}/layering_path_$timestamp.json';

      // Export as CSV
      await STLFileHandler.exportPathToCSV(generatedPath, csvPath);

      // Export as JSON
      await STLFileHandler.exportPathToJSON(
        generatedPath,
        jsonPath,
        name: 'Motorcycle Jacket Layering Path',
        metadata: {
          'standoffDistance': standoffDistance,
          'dotCount': dotCount,
          'sphereRadius': sphereRadius,
          'layerHeight': layerHeight,
          'totalPoints': generatedPath.length,
          'pathLength': algorithm?.calculatePathLength(generatedPath) ?? 0,
        },
      );

      setState(() => statusMessage = 'Exported to: $csvPath');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exported to Downloads folder'),
            backgroundColor: Color(0xFF00D9FF),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error exporting path: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: const Color(0xFFFF0000),
          ),
        );
      }
    }
  }
}
