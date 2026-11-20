/// 云端后端地址（`backend/` 下的 zuno-api Worker）。
///
/// 指向 Cloudflare 自定义域，而不是 `*.workers.dev`：后者在部分网络会被
/// DNS 投毒，解析到无关 IP，表现为“连接超时但服务正常”。
/// 换环境（本地 wrangler dev / 自建）只改这一处。
class ZunoEndpoint {
  ZunoEndpoint._();

  static const String base = 'https://zuno-api.zephyrisle.qzz.io';
}
