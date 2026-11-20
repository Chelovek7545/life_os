import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/utils/color_format.dart';

class ProjectColorPicker extends StatefulWidget {
  const ProjectColorPicker({
    super.key,
    required this.color,
    required this.onChanged,
    required this.enabled,
  });

  final Color color;
  final ValueChanged<Color> onChanged;
  final bool enabled;

  @override
  State<ProjectColorPicker> createState() => _ProjectColorPickerState();
}

class _ProjectColorPickerState extends State<ProjectColorPicker> {
  static final _hexPattern = RegExp(r'^#?[0-9a-fA-F]{6}$');
  late HSVColor _hsv = HSVColor.fromColor(widget.color.withValues(alpha: 1));
  late final _hex = TextEditingController(text: widget.color.toHex());
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant ProjectColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.color != oldWidget.color && widget.color != _hsv.toColor()) {
      _hsv = HSVColor.fromColor(widget.color.withValues(alpha: 1));
      _hex.text = widget.color.toHex();
    }
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _update(HSVColor hsv, {bool updateText = true}) {
    setState(() => _hsv = hsv);
    final color = hsv.toColor();
    if (updateText) _hex.text = color.toHex();
    widget.onChanged(color);
  }

  void _toggle() {
    if (_expanded) _hex.text = _hsv.toColor().toHex();
    setState(() => _expanded = !_expanded);
  }

  Widget _saturation() {
    return SizedBox(
      height: 84,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const radius = 8.0;
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          void select(Offset position) => _update(
            _hsv
                .withSaturation((position.dx / width).clamp(0, 1))
                .withValue((1 - position.dy / height).clamp(0, 1)),
          );
          return GestureDetector(
            onTapUp: widget.enabled
                ? (event) => select(event.localPosition)
                : null,
            onPanUpdate: widget.enabled
                ? (event) => select(event.localPosition)
                : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white,
                          HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor(),
                        ],
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black],
                      ),
                    ),
                  ),
                  Positioned(
                    left: (width - radius * 2) * _hsv.saturation,
                    top: (height - radius * 2) * (1 - _hsv.value),
                    child: Container(
                      width: radius * 2,
                      height: radius * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black54, blurRadius: 3),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _hue() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          left: 10,
          right: 10,
          child: Container(
            height: 9,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF0000),
                  Color(0xFFFFFF00),
                  Color(0xFF00FF00),
                  Color(0xFF00FFFF),
                  Color(0xFF0000FF),
                  Color(0xFFFF00FF),
                  Color(0xFFFF0000),
                ],
              ),
            ),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.transparent,
            inactiveTrackColor: Colors.transparent,
            disabledActiveTrackColor: Colors.transparent,
            disabledInactiveTrackColor: Colors.transparent,
            thumbColor: Colors.white,
            trackHeight: 0,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
          ),
          child: Semantics(
            label: 'Оттенок',
            child: Slider(
              value: _hsv.hue,
              max: 360,
              onChanged: widget.enabled
                  ? (hue) => _update(_hsv.withHue(hue))
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final swatch = Semantics(
      expanded: _expanded,
      value: widget.color.toHex(),
      child: OutlinedButton(
        onPressed: widget.enabled ? _toggle : null,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          side: BorderSide(color: AppColors.borderGlass),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            const Text('Цвет'),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.borderGlass),
              ),
            ),
            Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18),
          ],
        ),
      ),
    );
    final hex = SizedBox(
      width: 108,
      child: TextFormField(
        controller: _hex,
        readOnly: !widget.enabled,
        decoration: InputDecoration(
          labelText: 'HEX',
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
        ),
        validator: (value) =>
            _hexPattern.hasMatch(value?.trim() ?? '') ? null : 'Неверный HEX',
        onChanged: (value) {
          final hex = value.trim();
          if (_hexPattern.hasMatch(hex)) {
            _update(HSVColor.fromColor(parseHexColor(hex)), updateText: false);
          }
        },
      ),
    );
    final palette = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_saturation(), _hue()],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 500;
        final panel = DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderGlass),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 4),
            child: wide
                ? Row(
                    spacing: 18,
                    children: [
                      Expanded(child: palette),
                      hex,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 8,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: hex,
                      ),
                      palette,
                    ],
                  ),
          ),
        );
        return wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 18,
                children: [
                  swatch,
                  if (_expanded) Expanded(child: panel),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [swatch, if (_expanded) panel],
              );
      },
    );
  }
}
