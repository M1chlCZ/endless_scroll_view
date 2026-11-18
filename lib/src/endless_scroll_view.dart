import 'package:material_ui/material_ui.dart';

import 'endless_scroll_style.dart';

/// A scroll view that requests more items when the user nears the end.
///
/// The widget owns the scroll mechanics and the footer. The caller owns the
/// data, the paging state and the network calls. It works with any state
/// management, including Riverpod, Bloc or plain `setState`.
///
/// The caller must set [isLoadingMore] while a request runs and set
/// [hasMore] to false when the server has no more items. Otherwise the
/// widget keeps requesting as long as the content does not fill the
/// viewport.
class EndlessScrollView extends StatefulWidget {
  /// Creates an [EndlessScrollView].
  const EndlessScrollView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.onLoadMore,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.loadMoreError,
    this.onRetry,
    this.threshold = 400,
    this.padding,
    this.physics,
    this.separatorBuilder,
    this.emptyBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.endOfListBuilder,
    this.onRefresh,
    this.placeholderItemBuilder,
    this.placeholderCount = 6,
    this.controller,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
  }) : assert(placeholderCount > 0),
       assert(
         onRefresh == null || scrollDirection == Axis.vertical,
         'onRefresh requires a vertical list',
       );

  /// The number of loaded items.
  final int itemCount;

  /// Builds the item at the given index.
  final IndexedWidgetBuilder itemBuilder;

  /// Requests the next page. The widget calls it once per content change.
  final VoidCallback onLoadMore;

  /// Whether more items exist. The widget stops requesting when false.
  final bool hasMore;

  /// Whether a request runs. The widget pauses requests while true.
  final bool isLoadingMore;

  /// The error of the last failed request, or null.
  ///
  /// While it is set, the footer shows [errorBuilder] and the widget stops
  /// requesting.
  final Object? loadMoreError;

  /// Called when the user taps the retry button of the default error footer.
  final VoidCallback? onRetry;

  /// The distance in pixels from the end that starts the next request.
  final double threshold;

  /// The padding around the list.
  final EdgeInsetsGeometry? padding;

  /// The scroll physics of the list.
  final ScrollPhysics? physics;

  /// Builds a separator between two items. The footer has no separator.
  final IndexedWidgetBuilder? separatorBuilder;

  /// Shown instead of the list when no items are loaded.
  final WidgetBuilder? emptyBuilder;

  /// Shown in the footer while a request runs.
  final WidgetBuilder? loadingBuilder;

  /// Shown in the footer after a failed request.
  final WidgetBuilder? errorBuilder;

  /// Shown in the footer when no more items exist.
  final WidgetBuilder? endOfListBuilder;

  /// Called when the user pulls the list down to refresh it.
  ///
  /// When set, the widget wraps the list in a [RefreshIndicator]. A short
  /// list and the empty state stay pullable.
  final Future<void> Function()? onRefresh;

  /// Builds one placeholder row shown while the first page loads.
  ///
  /// When the list is empty, a request runs and this builder is set, the
  /// widget shows [placeholderCount] placeholder rows instead of
  /// [emptyBuilder].
  final IndexedWidgetBuilder? placeholderItemBuilder;

  /// Number of placeholder rows shown during the first load.
  ///
  /// Defaults to `6`. Must be positive.
  final int placeholderCount;

  /// The scroll controller of the list.
  ///
  /// Pass one to drive the list from a scroll-to-top button. When null, the
  /// widget creates and disposes its own controller.
  final ScrollController? controller;

  /// The axis of the list.
  ///
  /// Defaults to [Axis.vertical].
  final Axis scrollDirection;

  /// Whether the list starts at the end.
  ///
  /// Use `true` with [Axis.vertical] for a chat history whose newest item is
  /// at index 0.
  final bool reverse;

  @override
  State<EndlessScrollView> createState() => _EndlessScrollViewState();
}

class _EndlessScrollViewState extends State<EndlessScrollView> {
  final ScrollController _internalController = ScrollController();
  var _loadRequested = false;

  ScrollController get _controller => widget.controller ?? _internalController;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());
  }

  @override
  void didUpdateWidget(EndlessScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _internalController).removeListener(_onScroll);
      _controller.addListener(_onScroll);
    }
    if (oldWidget.isLoadingMore && !widget.isLoadingMore) {
      _loadRequested = false;
    }
    if (oldWidget.loadMoreError != null && widget.loadMoreError == null) {
      _loadRequested = false;
    }
    if (widget.itemCount != oldWidget.itemCount) {
      _loadRequested = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _internalController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_controller.position.extentAfter <= widget.threshold) {
      _maybeLoadMore();
    }
  }

  void _maybeLoadMore() {
    if (!mounted ||
        _loadRequested ||
        !widget.hasMore ||
        widget.isLoadingMore ||
        widget.loadMoreError != null ||
        !_controller.hasClients) {
      return;
    }
    if (_controller.position.extentAfter > widget.threshold) {
      return;
    }
    _loadRequested = true;
    widget.onLoadMore();
  }

  int get _footerCount {
    if (widget.isLoadingMore || widget.loadMoreError != null) {
      return 1;
    }
    if (!widget.hasMore && widget.endOfListBuilder != null) {
      return 1;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0) {
      if (widget.isLoadingMore && widget.placeholderItemBuilder != null) {
        return _wrapRefresh(_placeholderList(context), scrollable: true);
      }
      return _wrapRefresh(
        widget.emptyBuilder?.call(context) ?? const SizedBox.shrink(),
        scrollable: false,
      );
    }
    final footerCount = _footerCount;
    final total = widget.itemCount + footerCount;
    final physics = _listPhysics;
    final Widget list;
    if (widget.separatorBuilder != null) {
      list = ListView.separated(
        controller: _controller,
        scrollDirection: widget.scrollDirection,
        reverse: widget.reverse,
        padding: widget.padding,
        physics: physics,
        itemCount: total,
        itemBuilder: (context, index) => index < widget.itemCount
            ? widget.itemBuilder(context, index)
            : _footer(context),
        separatorBuilder: (context, index) => index < widget.itemCount - 1
            ? widget.separatorBuilder!(context, index)
            : const SizedBox.shrink(),
      );
    } else {
      list = ListView.builder(
        controller: _controller,
        scrollDirection: widget.scrollDirection,
        reverse: widget.reverse,
        padding: widget.padding,
        physics: physics,
        itemCount: total,
        itemBuilder: (context, index) => index < widget.itemCount
            ? widget.itemBuilder(context, index)
            : _footer(context),
      );
    }
    return _wrapRefresh(list, scrollable: true);
  }

  ScrollPhysics? get _listPhysics => widget.onRefresh != null
      ? AlwaysScrollableScrollPhysics(parent: widget.physics)
      : widget.physics;

  Widget _placeholderList(BuildContext context) {
    final builder = widget.placeholderItemBuilder!;
    return ListView.builder(
      controller: _controller,
      scrollDirection: widget.scrollDirection,
      reverse: widget.reverse,
      padding: widget.padding,
      physics: _listPhysics,
      itemCount: widget.placeholderCount,
      itemBuilder: (context, index) => builder(context, index),
    );
  }

  Widget _wrapRefresh(Widget child, {required bool scrollable}) {
    final onRefresh = widget.onRefresh;
    if (onRefresh == null || widget.scrollDirection != Axis.vertical) {
      return child;
    }
    if (scrollable) {
      return RefreshIndicator(onRefresh: onRefresh, child: child);
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
              minHeight: constraints.maxHeight,
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    final style = EndlessScrollStyle.of(context);
    if (widget.isLoadingMore) {
      return widget.loadingBuilder?.call(context) ??
          Padding(
            padding: style?.footerPadding ?? const EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: style?.loadingColor),
            ),
          );
    }
    if (widget.loadMoreError != null) {
      return widget.errorBuilder?.call(context) ??
          Padding(
            padding: style?.footerPadding ?? const EdgeInsets.all(16),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'The next page failed to load.',
                    style: style?.errorTextStyle,
                  ),
                  if (widget.onRetry != null)
                    TextButton(
                      onPressed: widget.onRetry,
                      style: style?.retryStyle,
                      child: const Text('Retry'),
                    ),
                ],
              ),
            ),
          );
    }
    return widget.endOfListBuilder?.call(context) ?? const SizedBox.shrink();
  }
}
