import 'package:flutter/material.dart';

class ControlPanel extends StatefulWidget {
  final Function(double) onStandoffChanged;
  final Function(int) onDotCountChanged;
  final Function(double) onSphereRadiusChanged;
  final Function(double) onLayerHeightChanged;
  final Function() onLoadSTL;
  final Function() onExport;
  final Function() onRegeneratePath;
  final int currentDotCount;
  final double currentPathLength;
  final bool isLoading;

  const ControlPanel({
    Key? key,
    required this.onStandoffChanged,
    required this.onDotCountChanged,
    required this.onSphereRadiusChanged,
    required this.onLayerHeightChanged,
    required this.onLoadSTL,
    required this.onExport,
    required this.onRegeneratePath,
    this.currentDotCount = 0,
    this.currentPathLength = 0,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> {
  // Initialize all values directly with concrete values
  double _standoff = 0.3;
  int _dotCount = 2600;
  double _sphereRadius = 0.1;
  double _layerHeight = 0.2;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0x000f1436),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildSectionHeader('Material Layering'),
              const SizedBox(height: 20),

              // File loading
              ElevatedButton.icon(
                onPressed: widget.isLoading ? null : widget.onLoadSTL,
                icon: widget.isLoading
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(
                  widget.isLoading ? 'Loading...' : 'Load STL File',
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: const Color(0x000a0e27),
                ),
              ),

              const SizedBox(height: 30),

              // Parameters section
              _buildSectionHeader('Parameters'),
              const SizedBox(height: 16),

              // Standoff Distance
              _buildSliderControl(
                label: 'Standoff Distance',
                value: _standoff,
                min: 0.1,
                max: 2.0,
                divisions: 19,
                onChanged: (v) {
                  setState(() => _standoff = v);
                  widget.onStandoffChanged(v);
                },
                suffix: ' mm',
              ),

              const SizedBox(height: 16),

              // Dot Count
              _buildIntSliderControl(
                label: 'Dot Count',
                value: _dotCount,
                min: 100,
                max: 5000,
                divisions: 49,
                onChanged: (v) {
                  setState(() => _dotCount = v);
                  widget.onDotCountChanged(v);
                },
                suffix: ' points',
              ),

              const SizedBox(height: 16),

              // Sphere Radius
              _buildSliderControl(
                label: 'Sphere Radius',
                value: _sphereRadius,
                min: 0.05,
                max: 0.5,
                divisions: 45,
                onChanged: (v) {
                  setState(() => _sphereRadius = v);
                  widget.onSphereRadiusChanged(v);
                },
                suffix: ' mm',
              ),

              const SizedBox(height: 16),

              // Layer Height
              _buildSliderControl(
                label: 'Layer Height',
                value: _layerHeight,
                min: 0.1,
                max: 1.0,
                divisions: 9,
                onChanged: (v) {
                  setState(() => _layerHeight = v);
                  widget.onLayerHeightChanged(v);
                },
                suffix: ' mm',
              ),

              const SizedBox(height: 30),

              // Action buttons
              ElevatedButton.icon(
                onPressed: widget.onRegeneratePath,
                icon: const Icon(Icons.refresh),
                label: const Text('Regenerate Path'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white,
                ),
              ),

              const SizedBox(height: 12),

              ElevatedButton.icon(
                onPressed: widget.onExport,
                icon: const Icon(Icons.download),
                label: const Text(
                  'Export Path',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: const Color(0x000a0e27),
                ),
              ),

              const SizedBox(height: 30),

              // Stats section
              _buildSectionHeader('Statistics'),
              const SizedBox(height: 12),

              _buildStatItem('Total Points', '${widget.currentDotCount}'),
              _buildStatItem(
                'Path Length',
                '${widget.currentPathLength.toStringAsFixed(2)} units',
              ),
              _buildStatItem(
                  'Layers', '${(widget.currentDotCount / 100).ceil()}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
        ),
      ],
    );
  }

  Widget _buildSliderControl({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required Function(double) onChanged,
    String suffix = '',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${value.toStringAsFixed(2)}$suffix',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: Theme.of(context).colorScheme.primary,
            inactiveTrackColor: Colors.grey[800],
            thumbColor: Theme.of(context).colorScheme.primary,
            overlayColor:
                Theme.of(context).colorScheme.primary.withOpacity(0.2),
            trackHeight: 4,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildIntSliderControl({
    required String label,
    required int value,
    required int min,
    required int max,
    required int divisions,
    required Function(int) onChanged,
    String suffix = '',
  }) {
    final double doubleValue = value.toDouble();
    final double doubleMin = min.toDouble();
    final double doubleMax = max.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$value$suffix',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: Theme.of(context).colorScheme.primary,
            inactiveTrackColor: Colors.grey[800],
            thumbColor: Theme.of(context).colorScheme.primary,
            overlayColor:
                Theme.of(context).colorScheme.primary.withOpacity(0.2),
            trackHeight: 4,
          ),
          child: Slider(
            value: doubleValue.clamp(doubleMin, doubleMax),
            min: doubleMin,
            max: doubleMax,
            divisions: divisions,
            onChanged: (v) => onChanged(v.toInt()),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.grey[400],
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ],
      ),
    );
  }
}
