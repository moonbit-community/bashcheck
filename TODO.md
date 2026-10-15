# TODO

## ShellCheck 0.11.0 CLI 兼容性

- [ ] 修复 100 层 source 边界的诊断差异。
  - 当前 bashcheck 保留既有 parser 基线，报告 SC1092（达到 source 深度限制）。
  - 本地 ShellCheck 0.11.0 CLI 在相同场景报告 SC1093（疑似递归 source，忽略文件）。
  - 核实上游 CLI 行为并修正实现；恢复该场景的 oracle 对照，移除 `oracle=False` 例外。

- [ ] 修复 SC2154 在带引号变量上的位置差异。
  - 例如 `echo "$bar"`：bashcheck 指向第 6 列的引号，ShellCheck 指向第 7 列的 `$`。
  - 当前 oracle 对照把 SC2154 的列号归零，只比较诊断码、文件和行号。
  - 修正位置后移除列号归零逻辑，严格比较实际列号。

- [ ] 核实并修复重复诊断的数量差异。
  - 部分 source 场景中，ShellCheck CLI 与 bashcheck 输出的重复诊断数量不同。
  - 当前 oracle 对照按“诊断码、文件、行、列”转成集合后去重，无法发现出现次数的差异。
  - 明确产生重复诊断的原因并对齐行为；移除集合去重，保留重复项并比较出现次数。

- [ ] 恢复上述场景的严格 oracle 比较，并重新验证 wasm/native CLI 回归测试。
  - 相关比较逻辑位于 `scripts/test_source_cli.mjs`，当前例外记录于 `e2etests/README.md`。
  - 当前对照测试通过包含上述放宽条件，不能据此声称这些行为与 ShellCheck CLI 完全一致。
