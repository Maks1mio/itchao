import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../../core/utils/itch_cached_network_image.dart';
import '../../../../data/game_page_models.dart';

/// Горизонтальная полоса скриншотов + полноэкранный просмотр.
class GameScreenshotStrip extends StatelessWidget {
  const GameScreenshotStrip({
    required this.items,
    required this.titleColor,
    super.key,
  });

  static const thumbHeight = 180.0;
  static const thumbAspect = 16 / 9;

  final List<GameMediaItem> items;
  final Color titleColor;

  Future<void> _openViewer(BuildContext context, int index, Rect? originRect) async {
    final url = items[index].url;
    await precacheImage(NetworkImage(url), context);
    if (!context.mounted) {
      return;
    }
    _precacheNeighbors(context, index);

    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        fullscreenDialog: true,
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _ScreenshotViewerPage(
            items: items,
            initialIndex: index,
            originRect: originRect,
            openAnimation: animation,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
      ),
    );
  }

  void _precacheNeighbors(BuildContext context, int index) {
    for (final offset in [-1, 1]) {
      final i = index + offset;
      if (i < 0 || i >= items.length) {
        continue;
      }
      precacheImage(NetworkImage(items[i].url), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final thumbWidth = thumbHeight * thumbAspect;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Скриншоты',
            style: TextStyle(color: titleColor, fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: thumbHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return _ScreenshotThumbnail(
                item: item,
                width: thumbWidth,
                height: thumbHeight,
                onTap: (originRect) => _openViewer(context, index, originRect),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ScreenshotThumbnail extends StatefulWidget {
  const _ScreenshotThumbnail({
    required this.item,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final GameMediaItem item;
  final double width;
  final double height;
  final void Function(Rect? originRect) onTap;

  @override
  State<_ScreenshotThumbnail> createState() => _ScreenshotThumbnailState();
}

class _ScreenshotThumbnailState extends State<_ScreenshotThumbnail> {
  final _boundsKey = GlobalKey();

  Rect? _globalBounds() {
    final box = _boundsKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return null;
    }
    final topLeft = box.localToGlobal(Offset.zero);
    return topLeft & box.size;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1A1A),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => widget.onTap(_globalBounds()),
        child: SizedBox(
          key: _boundsKey,
          width: widget.width,
          height: widget.height,
          child: ItchCachedNetworkImage(
            url: widget.item.url,
            width: widget.width,
            height: widget.height,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}

class _ScreenshotViewerPage extends StatefulWidget {
  const _ScreenshotViewerPage({
    required this.items,
    required this.initialIndex,
    required this.openAnimation,
    this.originRect,
  });

  final List<GameMediaItem> items;
  final int initialIndex;
  final Rect? originRect;
  final Animation<double> openAnimation;

  @override
  State<_ScreenshotViewerPage> createState() => _ScreenshotViewerPageState();
}

class _ScreenshotViewerPageState extends State<_ScreenshotViewerPage> {
  late final PageController _pageController;
  late int _currentIndex;
  var _pageScrollEnabled = true;
  var _dismissDrag = 0.0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _pageScrollEnabled = true;
      _dismissDrag = 0;
    });
    for (final offset in [-1, 1]) {
      final i = index + offset;
      if (i < 0 || i >= widget.items.length) {
        continue;
      }
      precacheImage(NetworkImage(widget.items[i].url), context);
    }
  }

  void _onZoomChanged(bool zoomed) {
    if (_pageScrollEnabled == !zoomed) {
      return;
    }
    setState(() => _pageScrollEnabled = !zoomed);
  }

  void _onDismissDragUpdate(double deltaDy) {
    setState(() => _dismissDrag += deltaDy);
  }

  void _onDismissDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dismissDrag.abs() > 110 || velocity > 700) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _dismissDrag = 0);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final open = widget.openAnimation;
    final dragFade = (1 - (_dismissDrag.abs() / 300).clamp(0.0, 0.45));

    return AnimatedBuilder(
      animation: open,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(open.value);
        return ColoredBox(
          color: Color.lerp(Colors.transparent, Colors.black, t)!.withValues(alpha: dragFade),
          child: child,
        );
      },
      child: Transform.translate(
        offset: Offset(0, _dismissDrag),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pageController,
                physics: _pageScrollEnabled
                    ? const PageScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                itemCount: widget.items.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  final isOpening = index == widget.initialIndex;
                  return _ScreenshotViewerSlide(
                    url: widget.items[index].url,
                    originRect: isOpening ? widget.originRect : null,
                    openAnimation: isOpening ? open : null,
                    onZoomChanged: _onZoomChanged,
                    onDismissDragUpdate: _onDismissDragUpdate,
                    onDismissDragEnd: _onDismissDragEnd,
                  );
                },
              ),
              Positioned(
                top: top + 8,
                left: 8,
                right: 8,
                child: Opacity(
                  opacity: dragFade,
                  child: Row(
                    children: [
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                      const Spacer(),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Text(
                            '${_currentIndex + 1} / ${widget.items.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScreenshotViewerSlide extends StatefulWidget {
  const _ScreenshotViewerSlide({
    required this.url,
    required this.onZoomChanged,
    required this.onDismissDragUpdate,
    required this.onDismissDragEnd,
    this.originRect,
    this.openAnimation,
  });

  final String url;
  final Rect? originRect;
  final Animation<double>? openAnimation;
  final ValueChanged<bool> onZoomChanged;
  final ValueChanged<double> onDismissDragUpdate;
  final ValueChanged<DragEndDetails> onDismissDragEnd;

  @override
  State<_ScreenshotViewerSlide> createState() => _ScreenshotViewerSlideState();
}

class _ScreenshotViewerSlideState extends State<_ScreenshotViewerSlide>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  AnimationController? _zoomAnim;
  Animation<Matrix4>? _zoomMatrixAnim;
  var _zoomed = false;

  static const _doubleTapScale = 2.75;
  static const _maxScale = 5.0;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
  }

  @override
  void dispose() {
    _zoomAnim?.dispose();
    _transform.removeListener(_onTransform);
    _transform.dispose();
    super.dispose();
  }

  void _onTransform() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.02;
    if (zoomed != _zoomed) {
      _zoomed = zoomed;
      widget.onZoomChanged(zoomed);
    }
  }

  void _animateMatrix(Matrix4 target) {
    _zoomAnim?.dispose();
    _zoomAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _zoomMatrixAnim = Matrix4Tween(begin: _transform.value, end: target).animate(
      CurvedAnimation(parent: _zoomAnim!, curve: Curves.easeOutCubic),
    );
    void tick() => _transform.value = _zoomMatrixAnim!.value;
    _zoomAnim!.addListener(tick);
    _zoomAnim!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _zoomAnim?.removeListener(tick);
        _zoomAnim?.dispose();
        _zoomAnim = null;
        _zoomMatrixAnim = null;
      }
    });
    _zoomAnim!.forward();
  }

  Matrix4 _matrixAtScale(double scale, Offset focal) {
    final dx = (1 - scale) * focal.dx;
    final dy = (1 - scale) * focal.dy;
    final m = Matrix4.identity();
    m.translateByDouble(dx, dy, 0, 1);
    m.scaleByDouble(scale, scale, 1, 1);
    return m;
  }

  void _onDoubleTap(TapDownDetails details) {
    if (_transform.value.getMaxScaleOnAxis() > 1.05) {
      _animateMatrix(Matrix4.identity());
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    final focal = box != null
        ? box.globalToLocal(details.globalPosition)
        : details.localPosition;
    _animateMatrix(_matrixAtScale(_doubleTapScale, focal));
  }

  Rect _targetRect(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final size = MediaQuery.sizeOf(context);
    return Rect.fromLTWH(
      8,
      padding.top + 48,
      size.width - 16,
      size.height - padding.top - padding.bottom - 96,
    );
  }

  Rect _beginRect(Size screen) {
    return widget.originRect ??
        Rect.fromCenter(
          center: Offset(screen.width / 2, screen.height / 2),
          width: screen.width * 0.72,
          height: screen.width * 0.72 * 9 / 16,
        );
  }

  @override
  Widget build(BuildContext context) {
    final open = widget.openAnimation;
    final image = _ScreenshotImage(url: widget.url);
    final viewport = Padding(
      padding: EdgeInsets.fromLTRB(
        8,
        MediaQuery.paddingOf(context).top + 48,
        8,
        MediaQuery.paddingOf(context).bottom + 48,
      ),
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: _maxScale,
        panEnabled: true,
        scaleEnabled: true,
        clipBehavior: Clip.none,
        boundaryMargin: const EdgeInsets.all(96),
        child: image,
      ),
    );

    Widget body = viewport;
    if (open != null) {
      final screen = MediaQuery.sizeOf(context);
      final t = Curves.easeOutCubic.transform(open.value);
      final rect = Rect.lerp(_beginRect(screen), _targetRect(context), t)!;
      final radius = lerpDouble(8, 0, t)!;
      final zoomIn = ((t - 0.82) / 0.18).clamp(0.0, 1.0);
      body = Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            ignoring: t < 0.99,
            child: Opacity(opacity: zoomIn, child: viewport),
          ),
          if (t < 0.995)
            Positioned.fromRect(
              rect: rect,
              child: Opacity(
                opacity: 1 - zoomIn,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: image,
                ),
              ),
            ),
        ],
      );
    }

    return GestureDetector(
      onDoubleTapDown: _onDoubleTap,
      onVerticalDragUpdate: (details) {
        if (!_zoomed) {
          widget.onDismissDragUpdate(details.delta.dy);
        }
      },
      onVerticalDragEnd: (details) {
        if (!_zoomed) {
          widget.onDismissDragEnd(details);
        }
      },
      child: body,
    );
  }
}

class _ScreenshotImage extends StatelessWidget {
  const _ScreenshotImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: NetworkImage(url),
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.high,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
          ),
        );
      },
    );
  }
}
