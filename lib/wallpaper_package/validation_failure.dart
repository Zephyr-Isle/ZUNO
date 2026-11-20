/// 导入校验的失败报告。
///
/// 任何一步失败即整包拒绝导入（规格），失败原因逐条列出，UI 直接展示给用户。
enum IssueCode {
  zipInvalid('ZIP 无法解压'),
  zipSlip('ZIP 路径遍历攻击'),
  manifestMissing('manifest.json 缺失'),
  manifestUnreadable('manifest.json 无法解析'),
  fieldInvalid('字段非法'),
  entryMissing('入口文件不存在'),
  contentEmpty('content/ 为空'),
  checksumMismatch('校验和不匹配'),
  minSdkTooHigh('包要求的 minSdk 高于本机系统'),
  timedScheduleInvalid('schedule.json 非法'),
  timedSlotMissing('schedule 引用的子壁纸不存在'),
  timedSlotInvalid('子壁纸 manifest 非法'),
  unknown('未知错误');

  const IssueCode(this.label);

  final String label;
}

class ValidationIssue {
  const ValidationIssue(this.code, this.message);

  final IssueCode code;
  final String message;

  @override
  String toString() => '[${code.label}] $message';
}

/// 导入失败结果（与成功结果 [ImportOutcome] 构成判别联合）。
class ImportFailure {
  const ImportFailure(this.issues);

  final List<ValidationIssue> issues;
}
