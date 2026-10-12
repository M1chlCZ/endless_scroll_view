import 'dart:async';
import 'dart:convert';

import 'package:atomic_ui_kit/atomic_ui_kit.dart';
import 'package:endless_scroll_view/endless_scroll_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:json_rest_client/json_rest_client.dart';

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

/// The state of a paged list.
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

/// A fake repository with a short delay, so the first tabs run offline.
class FakeRepository {
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

/// Loads pages from the fake repository.
class FakeItemsNotifier extends Notifier<PagedItems> {
  final FakeRepository _repository = FakeRepository();

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

final fakeItemsProvider = NotifierProvider<FakeItemsNotifier, PagedItems>(
  FakeItemsNotifier.new,
);

/// The bundled character pages. The example needs no network.
const characterPages = <int, Map<String, Object?>>{
  1: {
    'info': {'next': 'page-2'},
    'results': [
      {'name': 'Ada Lovelace'},
      {'name': 'Alan Turing'},
      {'name': 'Grace Hopper'},
      {'name': 'Edsger Dijkstra'},
      {'name': 'Barbara Liskov'},
    ],
  },
  2: {
    'info': {'next': 'page-3'},
    'results': [
      {'name': 'Donald Knuth'},
      {'name': 'Margaret Hamilton'},
      {'name': 'Ken Thompson'},
      {'name': 'Radia Perlman'},
      {'name': 'Tony Hoare'},
    ],
  },
  3: {
    'info': {'next': null},
    'results': [
      {'name': 'Katherine Johnson'},
      {'name': 'Dennis Ritchie'},
    ],
  },
};

/// Answers `GET /character` from the bundled pages.
class LocalJsonClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
    final body = jsonEncode(
      characterPages[page] ??
          const {
            'info': {'next': null},
            'results': [],
          },
    );
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

/// One page of characters.
class CharacterPage {
  const CharacterPage({required this.names, required this.hasMore});

  final List<String> names;
  final bool hasMore;

  /// Decodes one response of `GET /character`.
  static CharacterPage fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    final results = (map['results'] as List).cast<Map<String, dynamic>>();
    final info = map['info'] as Map<String, dynamic>;
    return CharacterPage(
      names: [for (final result in results) result['name'] as String],
      hasMore: info['next'] != null,
    );
  }
}

/// Reads no token. The bundled transport needs none.
class EmptyTokenStore implements TokenStore {
  @override
  Future<String?> read(String key) async => null;
}

/// The number of characters per page.
const characterPageSize = 5;

/// Loads the bundled character pages through json_rest_client.
class CharactersNotifier extends Notifier<PagedItems> {
  final JsonRestClient _client = JsonRestClient(
    baseUrl: 'https://characters.example/api',
    client: LocalJsonClient(),
    tokenStore: EmptyTokenStore(),
  );

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
      final page = await _client.get<CharacterPage>(
        '/character',
        query: {'page': '${state.items.length ~/ characterPageSize + 1}'},
        decoder: CharacterPage.fromJson,
      );
      final resolved = page ?? const CharacterPage(names: [], hasMore: false);
      state = state.copyWith(
        items: [...state.items, ...resolved.names],
        isLoading: false,
        hasMore: resolved.hasMore,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error);
    }
  }
}

final charactersProvider = NotifierProvider<CharactersNotifier, PagedItems>(
  CharactersNotifier.new,
);

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'endless_scroll_view example',
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        extensions: const [
          EndlessScrollStyle(footerPadding: EdgeInsets.all(24)),
        ],
      ),
      home: const HomeTabs(),
    );
  }
}

class HomeTabs extends StatelessWidget {
  const HomeTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('endless_scroll_view'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Riverpod'),
              Tab(text: 'atomic_ui_kit'),
              Tab(text: 'json_rest_client'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [FakeItemsPage(), StyledItemsPage(), CharactersPage()],
        ),
      ),
    );
  }
}

/// The Riverpod tab: a fake offline repository.
class FakeItemsPage extends ConsumerWidget {
  const FakeItemsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fakeItemsProvider);
    final notifier = ref.read(fakeItemsProvider.notifier);
    return EndlessScrollView(
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
      endOfListBuilder: (context) =>
          const Center(child: Text('All items loaded.')),
    );
  }
}

/// The atomic_ui_kit tab: neumorphic footers.
class StyledItemsPage extends ConsumerWidget {
  const StyledItemsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fakeItemsProvider);
    final notifier = ref.read(fakeItemsProvider.notifier);
    return EndlessScrollView(
      itemCount: state.items.length,
      itemBuilder: (context, index) =>
          ListTile(title: Text(state.items[index])),
      onLoadMore: notifier.loadMore,
      isLoadingMore: state.isLoading,
      hasMore: state.hasMore,
      loadMoreError: state.error,
      onRetry: notifier.loadMore,
      emptyBuilder: (context) =>
          const Center(child: CircularProgressIndicator()),
      loadingBuilder: (context) => const Padding(
        padding: EdgeInsets.all(16),
        child: NeuContainer(child: Center(child: CircularProgressIndicator())),
      ),
      endOfListBuilder: (context) => const Padding(
        padding: EdgeInsets.all(16),
        child: NeuContainer(child: Center(child: Text('All items loaded.'))),
      ),
    );
  }
}

/// The json_rest_client tab: bundled JSON through a local transport.
class CharactersPage extends ConsumerWidget {
  const CharactersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(charactersProvider);
    final notifier = ref.read(charactersProvider.notifier);
    return EndlessScrollView(
      itemCount: state.items.length,
      itemBuilder: (context, index) =>
          ListTile(title: Text(state.items[index])),
      onLoadMore: notifier.loadMore,
      isLoadingMore: state.isLoading,
      hasMore: state.hasMore,
      loadMoreError: state.error,
      onRetry: notifier.loadMore,
      emptyBuilder: (context) =>
          const Center(child: CircularProgressIndicator()),
      errorBuilder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('The characters failed to load.'),
            TextButton(
              onPressed: notifier.loadMore,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
