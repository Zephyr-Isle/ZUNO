import 'package:zuno/l10n/zuno_strings.dart';

/// 导入校验的失败报告。
///
/// 任何一步失败即整包拒绝导入（规格），失败原因逐条列出，UI 直接展示给用户。
/// 标签按当前 [ZunoStrings.current] 本地化；后台 isolate 会先按用户语言设置
/// 当前字符串表，再执行导入校验。
enum IssueCode {
  zipInvalid,
  zipSlip,
  manifestMissing,
  manifestUnreadable,
  fieldInvalid,
  entryMissing,
  contentEmpty,
  checksumMismatch,
  minSdkTooHigh,
  timedScheduleInvalid,
  timedSlotMissing,
  timedSlotInvalid,
  unknown;

  const IssueCode();

  String get label => ZunoStrings.current.issueLabel(name);
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
