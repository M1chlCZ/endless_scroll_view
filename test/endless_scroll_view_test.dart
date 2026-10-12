import 'dart:async';

import 'package:endless_scroll_view/endless_scroll_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the loaded items', (tester) async {
    await tester.pumpWidget(const _Harness(initialCount: 3));

    expect(find.text('Item 0'), findsOneWidget);
    expect(find.text('Item 2'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('calls onLoadMore when the user nears the end', (tester) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_Harness(key: key, initialCount: 20));
    expect(key.currentState!.loadCalls, 0);

    await tester.drag(find.byType(ListView), const Offset(0, -1300));
    await tester.pump();

    expect(key.currentState!.loadCalls, 1);
    await tester.pumpAndSettle();
  });

  testWidgets('does not call again while a request runs', (tester) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(
      _Harness(key: key, initialCount: 20, autoComplete: false),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -1300));
    await tester.pump();
    expect(key.currentState!.loadCalls, 1);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump();
    expect(key.currentState!.loadCalls, 1);

    key.currentState!.completeLoad();
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -2500));
    await tester.pump();
    expect(key.currentState!.loadCalls, 2);
  });

  testWidgets('does not call when hasMore is false', (tester) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(
      _Harness(key: key, initialCount: 20, hasMore: false),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -1400));
    await tester.pump();

    expect(key.currentState!.loadCalls, 0);
  });

  testWidgets('shows the loading footer while a request runs', (tester) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(
      _Harness(key: key, initialCount: 20, autoComplete: false),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -1300));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byType(CircularProgressIndicator),
      200,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    key.currentState!.completeLoad();
    await tester.pumpAndSettle();
  });

  testWidgets('shows the error footer and retries', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      _Harness(initialCount: 20, error: 'boom', onRetry: () => retries++),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -1400));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('The next page failed to load.'),
      200,
    );

    expect(find.text('The next page failed to load.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(retries, 1);
  });

  testWidgets('shows the empty builder when no items are loaded', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Harness(initialCount: 0, emptyBuilder: (_) => const Text('Nothing')),
    );

    expect(find.text('Nothing'), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('loads the first page when the content is short', (tester) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_Harness(key: key, initialCount: 3));

    expect(key.currentState!.loadCalls, 1);
    await tester.pumpAndSettle();
    expect(key.currentState!.loadCalls, 1);
  });

  testWidgets('shows the end of list footer when hasMore is false', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Harness(
        initialCount: 3,
        hasMore: false,
        endOfListBuilder: (_) => const Text('All loaded'),
      ),
    );

    expect(find.text('All loaded'), findsOneWidget);
  });

  testWidgets('applies the style to the error footer', (tester) async {
    await tester.pumpWidget(
      _Harness(
        initialCount: 20,
        error: 'boom',
        onRetry: () {},
        style: const EndlessScrollStyle(
          errorTextStyle: TextStyle(color: Color(0xFF112233)),
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -1400));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('The next page failed to load.'),
      200,
    );

    final text = tester.widget<Text>(
      find.text('The next page failed to load.'),
    );
    expect(text.style?.color, const Color(0xFF112233));
  });

  testWidgets('applies the style to the loading footer', (tester) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(
      _Harness(
        key: key,
        initialCount: 20,
        autoComplete: false,
        style: const EndlessScrollStyle(loadingColor: Color(0xFF445566)),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -1300));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byType(CircularProgressIndicator),
      200,
    );

    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(spinner.color, const Color(0xFF445566));
    key.currentState!.completeLoad();
    await tester.pumpAndSettle();
  });
}

class _Harness extends StatefulWidget {
  const _Harness({
    super.key,
    this.initialCount = 10,
    this.hasMore = true,
    this.error,
    this.onRetry,
    this.autoComplete = true,
    this.emptyBuilder,
    this.endOfListBuilder,
    this.style,
  });

  final int initialCount;
  final bool hasMore;
  final Object? error;
  final VoidCallback? onRetry;
  final bool autoComplete;
  final WidgetBuilder? emptyBuilder;
  final WidgetBuilder? endOfListBuilder;
  final EndlessScrollStyle? style;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late int count = widget.initialCount;
  var loading = false;
  var loadCalls = 0;
  Completer<void>? _pending;

  Future<void> _load() async {
    loadCalls++;
    setState(() => loading = true);
    if (!widget.autoComplete) {
      _pending = Completer<void>();
      await _pending!.future;
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    if (!mounted) {
      return;
    }
    setState(() {
      count += 10;
      loading = false;
    });
  }

  void completeLoad() => _pending?.complete();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(extensions: [if (widget.style != null) widget.style!]),
      home: Scaffold(
        body: EndlessScrollView(
          itemCount: count,
          itemBuilder: (context, index) =>
              SizedBox(height: 100, child: Text('Item $index')),
          onLoadMore: _load,
          hasMore: widget.hasMore,
          isLoadingMore: loading,
          loadMoreError: widget.error,
          onRetry: widget.onRetry,
          emptyBuilder: widget.emptyBuilder,
          endOfListBuilder: widget.endOfListBuilder,
        ),
      ),
    );
  }
}
