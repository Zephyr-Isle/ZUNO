/// esbuild 以 text loader 内联 schema.sql（见 bundle:selfhost 脚本）；
/// 这个声明只服务于 tsc 的模块解析。
declare module '*.sql' {
  const content: string;
  export default content;
}
