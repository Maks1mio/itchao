import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class UiInspectorOverlay extends StatefulWidget {
  const UiInspectorOverlay({
    required this.enabled,
    required this.child,
    super.key,
  });

  final bool enabled;
  final Widget child;

  @override
  State<UiInspectorOverlay> createState() => _UiInspectorOverlayState();
}

class _InspectorSelection {
  const _InspectorSelection({
    required this.widgetDesc,
    required this.renderType,
    required this.parents,
    required this.rect,
    required this.tap,
  });

  final String widgetDesc;
  final String renderType;
  final List<String> parents;
  final Rect rect;
  final Offset tap;
}

class _UiInspectorOverlayState extends State<UiInspectorOverlay> {
  _InspectorSelection? _selection;

  static const _skipRenderTypes = {
    'RenderView',
    'RenderPointerListener',
    'RenderIgnorePointer',
    'RenderAbsorbPointer',
    'RenderSemanticsAnnotations',
    'RenderSemanticsGestureHandler',
    'RenderTapRegionSurface',
    '_RenderTheater',
    '_RenderInkFeatures',
    'RenderPhysicalModel',
    'RenderPhysicalShape',
    'RenderMouseRegion',
    'RenderOffstage',
  };

  @override
  void didUpdateWidget(covariant UiInspectorOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) {
      setState(() => _selection = null);
    }
  }

  bool _shouldSkip(RenderObject target) {
    if (target is RenderView) {
      return true;
    }
    if (!target.attached) {
      return true;
    }
    if (_skipRenderTypes.contains(target.runtimeType.toString())) {
      return true;
    }
    if (target is! RenderBox || !target.hasSize) {
      return true;
    }
    final size = target.size;
    return size.width <= 1 || size.height <= 1;
  }

  Rect _globalRect(RenderBox box) {
    final transform = box.getTransformTo(null);
    return MatrixUtils.transformRect(transform, box.paintBounds);
  }

  RenderBox? _pickTarget(HitTestResult hit, Offset tapPosition, Size screenSize) {
    RenderBox? best;
    var bestArea = double.infinity;
    final screenArea = screenSize.width * screenSize.height;

    for (final entry in hit.path) {
      final target = entry.target;
      if (target is! RenderObject || _shouldSkip(target)) {
        continue;
      }
      if (target is! RenderBox || !target.hasSize) {
        continue;
      }
      final box = target;
      final rect = _globalRect(box);
      if (!rect.contains(tapPosition)) {
        continue;
      }
      final area = rect.width * rect.height;
      if (area >= screenArea * 0.92) {
        continue;
      }
      if (area < bestArea) {
        bestArea = area;
        best = box;
      }
    }

    return best;
  }

  Element? _elementFor(RenderObject renderObject) {
    final creator = renderObject.debugCreator;
    if (creator is Element) {
      return creator;
    }
    Element? found;
    void visitor(Element element) {
      if (found != null) {
        return;
      }
      if (identical(element.renderObject, renderObject)) {
        found = element;
        return;
      }
      element.visitChildren(visitor);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visitor);
    return found;
  }

  String _describeWidget(Element? element) {
    if (element == null) {
      return 'UnknownWidget';
    }
    final w = element.widget;
    final type = w.runtimeType.toString();
    if (w.key != null) {
      return '$type key=${w.key}';
    }
    if (w is Text) {
      final data = w.data ?? w.textSpan?.toPlainText() ?? '';
      final preview = data.length > 60 ? '${data.substring(0, 60)}…' : data;
      if (preview.isNotEmpty) {
        return '$type("$preview")';
      }
    }
    if (w is Image && w.image is NetworkImage) {
      return '$type(${(w.image as NetworkImage).url})';
    }
    return type;
  }

  List<String> _parentChain(Element? element) {
    if (element == null) {
      return const [];
    }
    final chain = <String>[];
    element.visitAncestorElements((ancestor) {
      chain.add(ancestor.widget.runtimeType.toString());
      return chain.length < 5;
    });
    return chain;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled) {
      return;
    }

    final hit = HitTestResult();
    WidgetsBinding.instance.hitTestInView(
      hit,
      event.position,
      View.of(context).viewId,
    );

    final screenSize = MediaQuery.sizeOf(context);
    final selected = _pickTarget(hit, event.position, screenSize);
    if (selected == null) {
      debugPrint(
        '[UI-INSPECTOR] tap=(${event.position.dx.toStringAsFixed(1)}, '
        '${event.position.dy.toStringAsFixed(1)}) — элемент не найден',
      );
      return;
    }

    final selectedElement = _elementFor(selected);
    final rect = _globalRect(selected);
    final widgetDesc = _describeWidget(selectedElement);
    final parents = _parentChain(selectedElement);

    setState(() {
      _selection = _InspectorSelection(
        widgetDesc: widgetDesc,
        renderType: selected.runtimeType.toString(),
        parents: parents,
        rect: rect,
        tap: event.position,
      );
    });

    debugPrint(
      '[UI-INSPECTOR] widget=$widgetDesc render=${selected.runtimeType} '
      'rect=(${rect.left.toStringAsFixed(1)}, ${rect.top.toStringAsFixed(1)}, '
      '${rect.width.toStringAsFixed(1)}x${rect.height.toStringAsFixed(1)})',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    final selection = _selection;
    final screenSize = MediaQuery.sizeOf(context);
    final dockToBottom =
        selection != null && _panelAtBottom(selection, screenSize);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onPointerDown,
          child: widget.child,
        ),
        if (selection != null) ...[
          Positioned(
            left: selection.rect.left,
            top: selection.rect.top,
            width: selection.rect.width,
            height: selection.rect.height,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.redAccent, width: 2),
                  color: Colors.redAccent.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: dockToBottom ? null : 0,
            bottom: dockToBottom ? 0 : null,
            child: IgnorePointer(
              child: _InspectorInfoBar(
                selection: selection,
                dockToBottom: dockToBottom,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Панель внизу, если выделение в верхней половине экрана — и наоборот.
  bool _panelAtBottom(_InspectorSelection selection, Size screenSize) {
    return selection.rect.center.dy < screenSize.height / 2;
  }
}

class _InspectorInfoBar extends StatelessWidget {
  const _InspectorInfoBar({
    required this.selection,
    required this.dockToBottom,
  });

  final _InspectorSelection selection;
  final bool dockToBottom;

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    final contentPadding = dockToBottom
        ? EdgeInsets.fromLTRB(12, 10, 12, safe.bottom + 8)
        : EdgeInsets.fromLTRB(12, safe.top + 8, 12, 10);

    return Material(
      elevation: 8,
      color: const Color(0xEE1A1A1A),
      child: Container(
        width: double.infinity,
        padding: contentPadding,
        decoration: BoxDecoration(
          border: Border(
            top: dockToBottom
                ? BorderSide.none
                : const BorderSide(color: Colors.redAccent, width: 2),
            bottom: dockToBottom
                ? const BorderSide(color: Colors.redAccent, width: 2)
                : BorderSide.none,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'UI Inspector',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 4),
            _InfoLine(label: 'Widget', value: selection.widgetDesc),
            _InfoLine(label: 'Render', value: selection.renderType),
            _InfoLine(
              label: 'Rect',
              value: '${selection.rect.left.toStringAsFixed(0)}, '
                  '${selection.rect.top.toStringAsFixed(0)} · '
                  '${selection.rect.width.toStringAsFixed(0)}×'
                  '${selection.rect.height.toStringAsFixed(0)}',
            ),
            _InfoLine(
              label: 'Tap',
              value: '${selection.tap.dx.toStringAsFixed(0)}, '
                  '${selection.tap.dy.toStringAsFixed(0)}',
            ),
            if (selection.parents.isNotEmpty)
              _InfoLine(
                label: 'Parents',
                value: selection.parents.join(' ← '),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, height: 1.35, color: Color(0xFFE8E8E8)),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Color(0xFF909090),
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
