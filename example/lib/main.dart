import 'dart:async';

import 'package:endless_scroll_view/endless_scroll_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: ExampleApp()));
}

/// The number of items per page.
const pageSize = 20;

/// One page of items.
class Page {
  const Page({required this.items, required this.hasMore});

  final List<String> items;
  final bool hasMore;
}

/// A fake repository with a short delay, so the example runs offline.
class ItemRepository {
  Future<Page> fetchPage(int page) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final start = (page - 1) * pageSize;
    return Page(
      items: [
        for (var index = start; index < start + pageSize; index++)
          'Item ${index + 1}',
      ],
      hasMore: page < 5,
    );
  }
}

/// The state of the paged list.
class PagedItems {
  const PagedItems({
    this.items = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  final List<String> items;
  final bool isLoading;
  final bool hasMore;
  final Object? error;

  PagedItems copyWith({
    List<String>? items,
    bool? isLoading,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) {
    return PagedItems(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Loads pages into one list.
class PagedItemsNotifier extends Notifier<PagedItems> {
  final ItemRepository _repository = ItemRepository();

  @override
  PagedItems build() {
    Future<void>.microtask(loadMore);
    return const PagedItems();
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) {
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await _repository.fetchPage(
        state.items.length ~/ pageSize + 1,
      );
      state = state.copyWith(
        items: [...state.items, ...page.items],
        isLoading: false,
        hasMore: page.hasMore,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error);
    }
  }
}

final pagedItemsProvider = NotifierProvider<PagedItemsNotifier, PagedItems>(
  PagedItemsNotifier.new,
);

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'endless_scroll_view example',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      home: const ItemsPage(),
    );
  }
}

class ItemsPage extends ConsumerWidget {
  const ItemsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pagedItemsProvider);
    final notifier = ref.read(pagedItemsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Endless scroll example')),
      body: EndlessScrollView(
        itemCount: state.items.length,
        itemBuilder: (context, index) =>
            ListTile(title: Text(state.items[index])),
        onLoadMore: notifier.loadMore,
        isLoadingMore: state.isLoading,
        hasMore: state.hasMore,
        loadMoreError: state.error,
        onRetry: notifier.loadMore,
        separatorBuilder: (context, index) => const Divider(height: 1),
        emptyBuilder: (context) =>
            const Center(child: CircularProgressIndicator()),
        endOfListBuilder: (context) => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('All items loaded.')),
        ),
      ),
    );
  }
}
