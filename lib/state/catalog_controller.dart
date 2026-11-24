import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:zuno/l10n/zuno_strings.dart';
import 'package:zuno/models/remote_wallpaper.dart';
import 'package:zuno/services/remote_api.dart';

/// 在线壁纸库（云端目录）的状态。
///
/// 只负责“拉目录”和“把包下载到临时文件”，导入与落库仍然走
/// [LibraryController]——两件事分开，下载失败不会污染本地库索引。
class CatalogController extends ChangeNotifier {
  CatalogController(this._api);

  final RemoteApi _api;

  List<RemoteWallpaper> _items = const [];
  String? _nextCursor;
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  /// 正在下载的条目：id → 进度（0–1，total 未知时为 null）。
  final Map<String, double?> _progress = {};

  List<RemoteWallpaper> get items => List.unmodifiable(_items);
  bool get loading => _loading;
  bool get loaded => _loaded;
  bool get hasMore => _nextCursor != null;
  String? get error => _error;

  bool isDownloading(String id) => _progress.containsKey(id);

  /// 列表卡片用的封面地址；没有封面时返回 null（卡片回落类型占位图）。
  /// 后端只下发 hasCover，不泄露 WebDAV 路径，真实封面由 Worker 代理。
  String? coverUrlOf(RemoteWallpaper item) => item.hasCover
      ? '${_api.baseUrl}/api/wallpapers/${Uri.encodeComponent(item.id)}/cover'
      : null;

  /// 进度百分比；`null` 表示总量未知（服务端没给 Content-Length）。
  double? progressOf(String id) => _progress[id];

  /// 首次进入页面时调用；已有数据则跳过（避免每次切页签都打请求）。
  Future<void> ensureLoaded() async {
    if (_loaded || _loading) return;
    await refresh();
  }

  /// 请求代次：地址切换 / 新一轮刷新会作废所有在途旧请求。
  ///
  /// 没有它会有跨端点数据污染：旧地址的目录请求还在途（最长 15s 超时），
  /// 用户在设置页保存新地址 → [reloadForNewEndpoint] 因 `_loading` 提前
  /// 返回不拉新数据，旧响应回来后反而把旧后端的条目灌进列表。
  int _generation = 0;

  /// 下拉/按钮刷新：回到第一页，并清掉上一轮错误。
  Future<void> refresh() async {
    if (_loading) return;
    _generation++;
    final gen = _generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await _api.listWallpapers();
      if (gen != _generation) return; // 已被新代次作废：丢弃响应
      _items = page.items;
      _nextCursor = page.nextCursor;
      _loaded = true;
    } on ApiException catch (error) {
      if (gen != _generation) return;
      _error = error.message;
    } catch (error) {
      if (gen != _generation) return;
      _error = ZunoStrings.current.errCatalogLoad(error);
    } finally {
      if (gen == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// 切换后端地址后重建目录：清空旧数据再拉第一页。
  ///
  /// 不能只调 [refresh]：旧后端的条目会残留在列表里，用户会误以为
  /// 新地址下也有那些壁纸。
  Future<void> reloadForNewEndpoint() async {
    // 作废在途的旧地址请求（哪怕它还占着 _loading），强制新一轮可发。
    // 旧请求回来时 gen 已不匹配，响应与 finally 都会静默丢弃。
    _generation++;
    _items = const [];
    _nextCursor = null;
    _loaded = false;
    _error = null;
    _loading = false;
    notifyListeners();
    await refresh();
  }

  /// 滚动到底时追加下一页。失败只在底部提示，不清空已加载内容。
  Future<void> loadMore() async {
    final cursor = _nextCursor;
    if (_loading || cursor == null) return;
    final gen = _generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await _api.listWallpapers(cursor: cursor);
      if (gen != _generation) return; // 地址已切换：丢弃过期分页
      // 按 id 去重：后端换页期间若有新条目插入，可能出现重复。
      final seen = _items.map((e) => e.id).toSet();
      _items = [
        ..._items,
        ...page.items.where((e) => seen.add(e.id)),
      ];
      _nextCursor = page.nextCursor;
    } on ApiException catch (error) {
      if (gen != _generation) return;
      _error = error.message;
    } catch (error) {
      if (gen != _generation) return;
      _error = ZunoStrings.current.errLoadMore(error);
    } finally {
      if (gen == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// 换取票据并把整包下载到缓存目录，返回本地文件。
  ///
  /// 不传 [token] 就是匿名下载（服务端记 `uid=anon`）——壁纸库是公开内容，
  /// 下载不再要求登录。
  /// 抛出的异常由调用方转成界面提示；下载失败会删除半截文件，
  /// 否则下一次重试会把它当成功结果导入而报 checksum 错误。
  Future<File> download(RemoteWallpaper item, {String? token}) async {
    if (_progress.containsKey(item.id)) {
      throw ApiException(
        0,
        'busy',
        ZunoStrings.current.errWallpaperDownloading,
      );
    }
    _progress[item.id] = null;
    notifyListeners();

    File? target;
    try {
      final ticket = await _api.requestTicket(
        wallpaperId: item.id,
        token: token,
      );
      final dir = Directory(
        '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}zuno_download',
      );
      await dir.create(recursive: true);
      final safeId = item.id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final file = File(
        '${dir.path}${Platform.pathSeparator}${safeId}_${item.version}.zuno',
      );
      target = file;
      if (await file.exists()) {
        await file.delete();
      }

      // 进度回调每收到一个 chunk 都会来；按 1% 或 200ms 节流，
      // 否则几十 MB 的包会触发上千次整页重建。
      var lastNotify = DateTime.now();
      var lastFraction = -1.0;
      await _api.downloadToFile(
        ticket.url,
        file,
        onProgress: (received, total) {
          final fraction = total == null || total <= 0
              ? null
              : (received / total).clamp(0.0, 1.0);
          final now = DateTime.now();
          final changed = fraction == null
              ? lastFraction < 0
              : (fraction - lastFraction).abs() >= 0.01;
          if (!changed && now.difference(lastNotify).inMilliseconds < 200) {
            return;
          }
          lastFraction = fraction ?? lastFraction;
          lastNotify = now;
          _progress[item.id] = fraction;
          notifyListeners();
        },
      );
      return file;
    } catch (error) {
      if (target != null && await target.exists()) {
        try {
          await target.delete();
        } catch (_) {
          // 清理失败交给系统缓存回收。
        }
      }
      rethrow;
    } finally {
      _progress.remove(item.id);
      notifyListeners();
    }
  }
}
