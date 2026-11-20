import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:zuno/models/remote_wallpaper.dart';
import 'package:zuno/services/remote_api.dart';
import 'package:zuno/state/catalog_controller.dart';

/// CatalogController 的目录竞态回归测试。
///
/// 覆盖「旧地址请求在途时保存新地址」的代次丢弃语义：没有 _generation
/// 防护时，reloadForNewEndpoint 会因 _loading 提前返回不拉新数据，旧响应
/// 回来后反而把旧后端的条目灌进列表（跨端点数据污染）。
void main() {
  RemoteWallpaper item(String id) => RemoteWallpaper.tryFromJson({
    'id': id,
    'title': id,
    'type': 'video',
    'version': '1.0.0',
    'size': 1024,
    'updatedAt': 1,
  })!;

  test('refresh 在途时 reloadForNewEndpoint：旧响应被丢弃，新数据生效', () async {
    final api = _QueuedApi([
      Completer<CatalogPage>(), // #1 初始 refresh（跨端点场景里的旧地址请求）
      Completer<CatalogPage>(), // #2 reloadForNewEndpoint 发起的新地址请求
    ]);
    final controller = CatalogController(api);
    final old = api.queue[0];
    final fresh = api.queue[1];

    // 1) 旧地址的目录请求发出（挂起在 #1 上）。
    final inFlight = controller.refresh();
    await _pump();
    expect(controller.loading, isTrue, reason: '首轮请求应处于加载中');

    // 2) 用户在设置页保存新地址：清空目录并强制新一轮请求。
    final reload = controller.reloadForNewEndpoint();

    // 3) 旧响应此刻才回来：必须被代次防护丢弃（不回填列表、不覆盖
    //    loading，也不会把 _loaded 置真）。
    old.complete(CatalogPage(items: [item('old-backend')]));
    await inFlight;
    await _pump();
    expect(controller.items, isEmpty, reason: '过期响应不得写入列表');
    expect(controller.loaded, isFalse);
    expect(controller.error, isNull);

    // 4) 新地址的响应回来：正常生效。
    fresh.complete(CatalogPage(items: [item('new-backend')]));
    await reload;
    expect(controller.items.map((e) => e.id), ['new-backend']);
    expect(controller.loaded, isTrue);
    expect(controller.loading, isFalse);
  });

  test('loadMore 的过期分页同样被代次丢弃', () async {
    final api = _QueuedApi([
      Completer<CatalogPage>(), // #1 首页
      Completer<CatalogPage>(), // #2 第二页（loadMore 在途时切换地址）
      Completer<CatalogPage>(), // #3 reloadForNewEndpoint 的新地址请求
    ]);
    final controller = CatalogController(api);
    final first = api.queue[0];
    final second = api.queue[1];
    final fresh = api.queue[2];

    final initial = controller.refresh();
    await _pump();
    first.complete(CatalogPage(items: [item('p1')], nextCursor: 'cursor-1'));
    await initial;
    expect(controller.items.map((e) => e.id), ['p1']);

    // 下一页在途时切换地址。
    final loadMore = controller.loadMore();
    await _pump();
    final reload = controller.reloadForNewEndpoint();
    // 过期的第二页此刻回来：不得追加进新地址的列表。
    second.complete(CatalogPage(items: [item('stale-page')]));
    await loadMore;
    await _pump();
    expect(controller.items, isEmpty, reason: '过期分页不得写入列表');

    fresh.complete(CatalogPage(items: [item('new-backend')]));
    await reload;
    expect(controller.items.map((e) => e.id), ['new-backend']);
    expect(controller.hasMore, isFalse);
  });
}

/// 按调用次序从队列弹出预设响应的假 API（不触网）。
class _QueuedApi extends RemoteApi {
  _QueuedApi(this.queue) : super(baseUrl: 'https://example.invalid');

  final List<Completer<CatalogPage>> queue;

  @override
  Future<CatalogPage> listWallpapers({String? cursor, int limit = 20}) {
    if (queue.isEmpty) return Completer<CatalogPage>().future;
    return queue.removeAt(0).future;
  }
}

/// 冲刷微任务队列，让挂起的 continuation 走完。
Future<void> _pump() => Future<void>.delayed(Duration.zero);
