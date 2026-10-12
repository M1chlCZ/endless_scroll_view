import 'package:flutter/material.dart';

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
  });

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

  @override
  State<EndlessScrollView> createState() => _EndlessScrollViewState();
}

class _EndlessScrollViewState extends State<EndlessScrollView> {
  final ScrollController _controller = ScrollController();
  var _loadRequested = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());
  }

  @override
  void didUpdateWidget(EndlessScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    _controller.dispose();
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
      return widget.emptyBuilder?.call(context) ?? const SizedBox.shrink();
    }
    final footerCount = _footerCount;
    final total = widget.itemCount + footerCount;
    if (widget.separatorBuilder != null) {
      return ListView.separated(
        controller: _controller,
        padding: widget.padding,
        physics: widget.physics,
        itemCount: total,
        itemBuilder: (context, index) => index < widget.itemCount
            ? widget.itemBuilder(context, index)
            : _footer(context),
        separatorBuilder: (context, index) => index < widget.itemCount - 1
            ? widget.separatorBuilder!(context, index)
            : const SizedBox.shrink(),
      );
    }
    return ListView.builder(
      controller: _controller,
      padding: widget.padding,
      physics: widget.physics,
      itemCount: total,
      itemBuilder: (context, index) => index < widget.itemCount
          ? widget.itemBuilder(context, index)
          : _footer(context),
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
                    'The next page could not be loaded.',
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
