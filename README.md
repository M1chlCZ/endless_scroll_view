# endless_scroll_view

A Flutter scroll view that loads more items when the user nears the end.

- One widget owns the scroll mechanics and the footer.
- The caller owns the data, the paging state and the network calls.
- It works with any state management: Riverpod, Bloc or plain `setState`.
- No dependencies beyond Flutter.

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

The [`example/`](example/) app shows a full Riverpod version with a
`Notifier`-based paged list. The wiring is short:

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
  most `threshold` (400 pixels by default). The check also runs after layout,
  so a short first page loads the next page without a scroll.
- The widget sends no requests while `isLoadingMore` is true, while
  `loadMoreError` is set, or when `hasMore` is false.
- After a request completes, or after the error clears, the check runs again,
  so the viewport fills.
- The footer shows the loading view while a request runs, the error view
  after a failure (with a retry button when `onRetry` is set), and the
  end-of-list view when `hasMore` is false and `endOfListBuilder` is set.
- When `itemCount` is 0, the widget shows `emptyBuilder`. Use it for the
  initial loading state too.

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
