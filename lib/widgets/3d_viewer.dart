import 'dart:async';
import 'package:dot_matrix/models/mesh_3d.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:three_dart/three_dart.dart' as three;
import 'package:vector_math/vector_math.dart' as vm;
import 'package:flutter_gl/flutter_gl.dart';

class ThreeDViewer extends StatefulWidget {
  final Mesh3D? mesh;
  final List<vm.Vector3> path;
  final double sphereRadius;
  final bool showMesh;
  final bool showPath;
  final bool showDots;

  const ThreeDViewer({
    Key? key,
    this.mesh,
    this.path = const [],
    this.sphereRadius = 0.1,
    this.showMesh = true,
    this.showPath = true,
    this.showDots = true,
  }) : super(key: key);

  @override
  State<ThreeDViewer> createState() => _ThreeDViewerState();
}

class _ThreeDViewerState extends State<ThreeDViewer> {
  late FlutterGlPlugin three3dRender;
  three.WebGLRenderer? renderer;

  late three.Scene scene;
  late three.PerspectiveCamera camera;
  three.Mesh? meshObject;
  three.LineSegments? pathLines;
  late three.Group dotsGroup;
  late three.Raycaster raycaster;
  late three.Vector2 mouse;

  double rotationX = 0;
  double rotationY = 0;
  bool isDragging = false;
  double zoomLevel = 1.0;

  Size? screenSize;
  late double width;
  late double height;
  double dpr = 1.0;

  dynamic sourceTexture;
  late three.WebGLRenderTarget renderTarget;

  @override
  void initState() {
    super.initState();
  }

  Future<void> initPlatformState() async {
    width = screenSize!.width;
    height = screenSize!.height;

    three3dRender = FlutterGlPlugin();

    Map<String, dynamic> options = {
      "antialias": true,
      "alpha": false,
      "width": width.toInt(),
      "height": height.toInt(),
      "dpr": dpr
    };

    await three3dRender.initialize(options: options);

    setState(() {});

    Future.delayed(const Duration(milliseconds: 200), () async {
      await three3dRender.prepareContext();

      // Wait for GL context to be fully ready
      if (three3dRender.gl != null) {
        initScene();
      }
    });
  }

  initSize(BuildContext context) {
    if (screenSize != null) {
      return;
    }

    final mqd = MediaQuery.of(context);
    screenSize = mqd.size;
    dpr = mqd.devicePixelRatio;

    initPlatformState();
  }

  void initRenderer() {
    if (three3dRender.gl == null) {
      print('GL context not ready, cannot initialize renderer');
      return;
    }

    Map<String, dynamic> options = {
      "width": width,
      "height": height,
      "gl": three3dRender.gl,
      "antialias": true,
      "canvas": three3dRender.element
    };

    try {
      renderer = three.WebGLRenderer(options);
      renderer!.setPixelRatio(dpr);
      renderer!.setSize(width, height, false);
      renderer!.shadowMap.enabled = true;

      if (!kIsWeb) {
        var pars = three.WebGLRenderTargetOptions({
          "minFilter": three.LinearFilter,
          "magFilter": three.LinearFilter,
          "format": three.RGBAFormat
        });
        renderTarget = three.WebGLRenderTarget(
            (width * dpr).toInt(), (height * dpr).toInt(), pars);
        renderer!.setRenderTarget(renderTarget);
        sourceTexture = renderer!.getRenderTargetGLTexture(renderTarget);
      }
    } catch (e) {
      print('Error initializing renderer: $e');
    }
  }

  void initScene() {
    initRenderer();

    scene = three.Scene();
    scene.background = three.Color(0x0a0e27);

    camera = three.PerspectiveCamera(
      75,
      width / height,
      0.1,
      10000,
    );
    camera.position.set(0, 0, 5);
    camera.lookAt(three.Vector3(0, 0, 0));

    // Lighting
    final ambientLight = three.AmbientLight(0xffffff, 0.6);
    scene.add(ambientLight);

    final directionalLight = three.DirectionalLight(0xffffff, 0.8);
    directionalLight.position.set(5, 5, 5);
    directionalLight.castShadow = true;
    scene.add(directionalLight);

    // Grid helper
    final grid = three.GridHelper(10, 10, 0x444444, 0x222222);
    scene.add(grid);

    // Axes helper
    final axes = three.AxesHelper(5);
    scene.add(axes);

    raycaster = three.Raycaster();
    mouse = three.Vector2();
    dotsGroup = three.Group();
    scene.add(dotsGroup);

    _updateScene();
    _animate();
  }

  void _updateScene() {
    // Remove old mesh
    scene.children.removeWhere((child) => child.name == 'stl-mesh');
    scene.children.removeWhere((child) => child.name == 'path-lines');

    // Add mesh
    if (widget.mesh != null && widget.showMesh) {
      _addMesh();
    }

    // Add path
    if (widget.path.isNotEmpty && widget.showPath) {
      _addPath();
    }

    // Update dots
    _updateDots();
  }

  void _addMesh() {
    if (widget.mesh == null) return;

    final vertices = widget.mesh!.vertices;
    final indices = widget.mesh!.indices;

    // Create geometry
    final geometry = three.BufferGeometry();

    final positionList = <double>[];
    for (int i = 0; i < vertices.length; i++) {
      positionList.add(vertices[i].x);
      positionList.add(vertices[i].y);
      positionList.add(vertices[i].z);
    }
    final positionArray = Float32Array.from(positionList);

    geometry.setAttribute(
      'position',
      three.Float32BufferAttribute(positionArray, 3),
    );

    if (indices.isNotEmpty) {
      final indexArray = Uint32Array.from(indices);
      geometry.setIndex(three.Uint32BufferAttribute(indexArray, 1));
    }

    geometry.computeVertexNormals();

    final material = three.MeshStandardMaterial({
      'color': 0xcccccc,
      'metalness': 0.3,
      'roughness': 0.7,
      'transparent': true,
      'opacity': 0.8,
      'side': three.DoubleSide,
    });

    final mesh = three.Mesh(geometry, material);
    mesh.name = 'stl-mesh';
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    scene.add(mesh);
    meshObject = mesh;
  }

  void _addPath() {
    if (widget.path.isEmpty) return;

    final points = widget.path;

    // Create line geometry
    final lineGeometry = three.BufferGeometry();
    final positionList = <double>[];

    for (int i = 0; i < points.length; i++) {
      positionList.add(points[i].x);
      positionList.add(points[i].y);
      positionList.add(points[i].z);
    }
    final positionArray = Float32Array.from(positionList);

    lineGeometry.setAttribute(
      'position',
      three.Float32BufferAttribute(positionArray, 3),
    );

    final lineMaterial = three.LineBasicMaterial({
      'color': 0x0099ff,
      'linewidth': 2,
      'transparent': true,
      'opacity': 0.7,
    });

    final lines = three.LineSegments(lineGeometry, lineMaterial);
    lines.name = 'path-lines';
    scene.add(lines);
    pathLines = lines;
  }

  void _updateDots() {
    // Clear old dots
    dotsGroup.children.clear();

    if (!widget.showDots || widget.path.isEmpty) return;

    // Create instanced sphere geometry for performance
    final sphereGeometry = three.SphereGeometry(widget.sphereRadius, 8, 8);
    final sphereMaterial = three.MeshStandardMaterial({
      'color': 0xff006e,
      'emissive': 0xff006e,
    });

    for (int i = 0; i < widget.path.length; i++) {
      final point = widget.path[i];

      final sphere = three.Mesh(sphereGeometry, sphereMaterial);
      sphere.position.set(point.x, point.y, point.z);
      sphere.castShadow = true;
      sphere.receiveShadow = true;

      dotsGroup.add(sphere);
    }
  }

  void _animate() {
    if (!mounted || renderer == null) return;

    // Auto-rotation when not dragging
    if (!isDragging) {
      meshObject?.rotation.y += 0.002;
      dotsGroup.rotation.y += 0.002;
      pathLines?.rotation.y += 0.002;
    }

    renderer!.render(scene, camera);

    final gl = three3dRender.gl;
    gl.flush();

    if (!kIsWeb) {
      three3dRender.updateTexture(sourceTexture);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animate();
    });
  }

  void _handleMouseDown(PointerDownEvent event) {
    isDragging = true;
  }

  void _handleMouseUp(PointerUpEvent event) {
    isDragging = false;
  }

  void _handleMouseMove(PointerMoveEvent event) {
    if (!isDragging) return;

    rotationY += event.delta.dx * 0.005;
    rotationX += event.delta.dy * 0.005;

    meshObject?.rotation.x = rotationX;
    meshObject?.rotation.y = rotationY;
    dotsGroup.rotation.x = rotationX;
    dotsGroup.rotation.y = rotationY;
    pathLines?.rotation.x = rotationX;
    pathLines?.rotation.y = rotationY;
  }

  void _handleScroll(PointerScrollEvent event) {
    zoomLevel += event.scrollDelta.dy * 0.001;
    zoomLevel = zoomLevel.clamp(0.1, 10.0);

    camera.position.set(0, 0, 5 * zoomLevel);
  }

  @override
  void didUpdateWidget(ThreeDViewer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.mesh != widget.mesh ||
        oldWidget.path != widget.path ||
        oldWidget.sphereRadius != widget.sphereRadius) {
      _updateScene();
    }
  }

  @override
  void dispose() {
    renderer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    initSize(context);

    return Listener(
      onPointerDown: _handleMouseDown,
      onPointerUp: _handleMouseUp,
      onPointerMove: _handleMouseMove,
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _handleScroll(event);
        }
      },
      child: Container(
        color: const Color(0xFF0a0e27),
        child: Stack(
          children: [
            // Three.js canvas
            screenSize != null
                ? SizedBox(
                    width: width,
                    height: height,
                    child: three3dRender.isInitialized
                        ? (kIsWeb
                            ? HtmlElementView(
                                viewType: three3dRender.textureId!.toString())
                            : Texture(textureId: three3dRender.textureId!))
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.view_in_ar,
                                  size: 80,
                                  color: Colors.grey[700],
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Initializing 3D viewer...',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.view_in_ar,
                          size: 80,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Load STL to view 3D model',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Points loaded: ${widget.path.length}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
            // Controls overlay
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0f1436).withAlpha(230),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF00d9ff).withAlpha(76),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '3D Controls',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Drag: Rotate',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'Scroll: Zoom',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
