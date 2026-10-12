# endless_scroll_view

[![CI](https://github.com/M1chlCZ/endless_scroll_view/actions/workflows/ci.yml/badge.svg)](https://github.com/M1chlCZ/endless_scroll_view/actions/workflows/ci.yml)
[![pub.dev](https://img.shields.io/pub/v/endless_scroll_view.svg)](https://pub.dev/packages/endless_scroll_view)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A Flutter scroll view that loads more items when the user nears the end.

- One widget owns the scroll mechanics and the footer.
- The caller owns the data, the paging state and the network calls.
- It works with any state management: Riverpod, Bloc or plain `setState`.
- The only dependency is Flutter.

## Install

```sh
flutter pub add endless_scroll_view
```

## Quick start

```dart
class ItemsPage extends StatefulWidget {
  const ItemsPage({super.key});

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  final List<String> items = [];
  var isLoading = false;
  var hasMore = true;
  Object? error;

  @override
  void initState() {
    super.initState();
    loadMore();
  }

  Future<void> loadMore() async {
    if (isLoading || !hasMore) return;
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final page = await repository.fetchPage(items.length ~/ 20 + 1);
      setState(() {
        items.addAll(page.items);
        hasMore = page.hasMore;
      });
    } catch (caught) {
      setState(() => error = caught);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EndlessScrollView(
      itemCount: items.length,
      itemBuilder: (context, index) => ListTile(title: Text(items[index])),
      onLoadMore: loadMore,
      isLoadingMore: isLoading,
      hasMore: hasMore,
      loadMoreError: error,
      onRetry: loadMore,
    );
  }
}
```

## Riverpod

The [`example/`](example/) app shows a Riverpod version with a `Notifier`
that loads pages. The wiring is short:

```dart
final state = ref.watch(pagedItemsProvider);

EndlessScrollView(
  itemCount: state.items.length,
  itemBuilder: (context, index) => ListTile(title: Text(state.items[index])),
  onLoadMore: ref.read(pagedItemsProvider.notifier).loadMore,
  isLoadingMore: state.isLoading,
  hasMore: state.hasMore,
  loadMoreError: state.error,
  onRetry: ref.read(pagedItemsProvider.notifier).loadMore,
);
```

## Behavior

- The widget requests the next page when the remaining scroll distance is at
  most `threshold`. The default is 400 pixels.
- The check also runs after layout. A short first page loads the next page
  without a scroll.
- The widget sends no request while `isLoadingMore` is true, while
  `loadMoreError` is set, or when `hasMore` is false.
- After a request completes, or after the error clears, the check runs again.
  The list then fills the viewport.
- The footer shows the loading view while a request runs. After a failure it
  shows the error view, with a retry button when `onRetry` is set. When
  `hasMore` is false and `endOfListBuilder` is set, it shows the end of list
  view.
- When `itemCount` is 0, the widget shows `emptyBuilder`. Use it for the
  initial loading state too.

## Styling

The default footer reads the `EndlessScrollStyle` theme extension. Register
it once and every endless list picks it up:

```dart
MaterialApp(
  theme: ThemeData(
    extensions: const [
      EndlessScrollStyle(
        loadingColor: Colors.teal,
        footerPadding: EdgeInsets.all(24),
      ),
    ],
  ),
);
```

| Field | Purpose |
| --- | --- |
| `loadingColor` | Color of the default loading indicator |
| `errorTextStyle` | Text style of the default error message |
| `retryStyle` | Button style of the default retry button |
| `footerPadding` | Padding around the default footer |

A custom `loadingBuilder`, `errorBuilder` or `endOfListBuilder` wins over the
style.

### With atomic_ui_kit

[atomic_ui_kit](https://pub.dev/packages/atomic_ui_kit) supplies the visuals
for a neumorphic footer:

```dart
EndlessScrollView(
  // ...
  loadingBuilder: (context) => const Padding(
    padding: EdgeInsets.all(16),
    child: NeuContainer(child: Center(child: CircularProgressIndicator())),
  ),
  endOfListBuilder: (context) => const Padding(
    padding: EdgeInsets.all(16),
    child: NeuContainer(child: Center(child: Text('All items loaded.'))),
  ),
);
```

## Using with other packages

The widget works with any data source. With
[json_rest_client](https://pub.dev/packages/json_rest_client) one page load
is short:

```dart
final client = JsonRestClient(
  baseUrl: 'https://api.example.com',
  tokenStore: tokenStore,
);

Future<Page> fetchPage(int page) async {
  final result = await client.get<Page>(
    '/items',
    query: {'page': '$page'},
    decoder: Page.fromJson,
  );
  return result ?? const Page(items: [], hasMore: false);
}
```

The [`example/`](example/) app shows all three wirings with bundled JSON: a
Riverpod list, an atomic_ui_kit-styled list and a json_rest_client list that
reads from a local transport. The example needs no network.

## API

| Parameter | Type | Default | Purpose |
| --- | --- | --- | --- |
| `itemCount` | `int` | required | The number of loaded items |
| `itemBuilder` | `IndexedWidgetBuilder` | required | Builds one item |
| `onLoadMore` | `VoidCallback` | required | Requests the next page |
| `hasMore` | `bool` | `true` | Stops requests when false |
| `isLoadingMore` | `bool` | `false` | Pauses requests while true |
| `loadMoreError` | `Object?` | `null` | Shows the error footer while set |
| `onRetry` | `VoidCallback?` | `null` | Retry button of the default error footer |
| `threshold` | `double` | `400` | Distance from the end that starts a request |
| `padding` | `EdgeInsetsGeometry?` | `null` | List padding |
| `physics` | `ScrollPhysics?` | `null` | List physics |
| `separatorBuilder` | `IndexedWidgetBuilder?` | `null` | Separator between two items |
| `emptyBuilder` | `WidgetBuilder?` | `null` | Shown when no items are loaded |
| `loadingBuilder` | `WidgetBuilder?` | `null` | Loading footer |
| `errorBuilder` | `WidgetBuilder?` | `null` | Error footer |
| `endOfListBuilder` | `WidgetBuilder?` | `null` | Footer when no more items exist |

## Notes and limitations

- The widget builds vertical lists only.
- Set `hasMore` to false when the server has no more items. Otherwise the
  widget keeps requesting while the content does not fill the viewport.
- The widget does not deduplicate items. The caller appends each page once.

## Development

```sh
flutter test
cd example && flutter run
```

## License

MIT. See [LICENSE](LICENSE).
