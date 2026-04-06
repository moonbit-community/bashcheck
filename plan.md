# bashcheck 对齐 ShellCheck 计划

## 范围

- 基准：`../shellcheck/src/`，并用本机 `shellcheck 0.11.0` 做 spot check。
- 非目标：CLI 返回值差异。
- 本轮对比方式：
  - 静态对照：按 `Analytics` / `Checks/Commands` / `Checks/ShellSupport` 的规则编号和实现入口做比对。
  - 动态对照：同一脚本分别跑 `shellcheck -f json` 和 `moon run bashcheck -- -f json`。

## 当前结论

1. 主要语义差异不在 CLI，而在 analyzer/rule coverage。
2. `parser` 从现有兼容测试和源码结构看已经比较接近上游；本轮没发现像 analyzer 一样成片缺失的 parser 模块，但诊断 span 仍需要补差分测试。
3. `checks/Commands` 基本对齐：
   - 静态抽取看，当前已覆盖约 `66/71` 个上游命令类规则。
   - 明确缺失：`SC2028`、`SC2155`、`SC2172`、`SC2173`、`SC2227`。
4. `checks/ShellSupport` 主体已对齐：
   - 当前已覆盖 `64/73` 个上游 `ShellSupport` 规则。
   - 明确缺失：`SC2001`、`SC2025`、`SC2051`、`SC2079`、`SC2175`、`SC2180`、`SC2325`、`SC2326`、`SC2332`。
5. `checks/Analytics` 是最大缺口：
   - 静态抽取看，当前仅覆盖约 `58/229` 个上游 analytics 规则。
   - 至少还缺 `171` 个规则号。
   - 缺口集中在 quoting/word-splitting、unused/constant/dataflow heuristics、find/read/pipeline/status 推理、arith/test pitfalls、command reasoning 等。
6. `checker` 入口层已有单独实现的规则不应误记为缺失：
   - `SC2148` 已在 `checker/driver.mbt` 处理。
   - `SC1134` 已在 `checker/config.mbt` 处理。

## 已确认的 spot check 差异

- `#!/bin/bash`
  `# shellcheck disable=SC2154`
  `echo $foo`
  - ShellCheck：报 `SC2086`
  - bashcheck：`[]`
- `#!/bin/bash`
  `foo=bar`
  - ShellCheck：报 `SC2034`
  - bashcheck：`[]`
- `#!/bin/bash`
  `echo "\\n"`
  - ShellCheck：报 `SC2028`
  - bashcheck：`[]`
- `#!/bin/bash`
  `f(){ local x=$(false); }`
  - ShellCheck：报 `SC2034` + `SC2155`
  - bashcheck：`[]`
- `#!/bin/bash`
  `echo {1..$n}`
  - ShellCheck：报 `SC2051` + `SC2086` + `SC2154`
  - bashcheck：只报了 `SC2154`，而且定位看起来偏了

## 优先级

### P0: 先补 differential harness

- 新增一个兼容性差分测试入口：
  - 同一输入分别跑 `shellcheck 0.11.0` 和 `bashcheck` JSON formatter。
  - 做统一 normalization：文件名、排序、severity 文本。
  - 明确忽略 CLI exit code。
- 第一批样例来源：
  - 现有 `compat/` 和 `checker/compat_regression_test.mbt`
  - 本文件列出的 spot check
  - Commands 的 5 个已知缺口
  - ShellSupport 的 9 个已知缺口
- 目标：
  - 先把“未对齐样例”固定成可回归的失败用例，再开始补实现。

### P1: Commands 尾差补齐

- 直接补齐 5 个明确缺口：
  - `SC2028`：`echo` escape 语义
  - `SC2155`：`local/declare/export/typeset` 与赋值掩盖返回值
  - `SC2172` / `SC2173`：`trap` 数字信号、不可捕获信号
  - `SC2227`：`find` 里重定向作用域错误
- 建议：
  - 新开一个 `commands_batch_d.mbt`，避免继续堆到现有 batch。
  - 每条规则补 `positive` / `negative` / `compat baseline` 三类测试。

### P1: ShellSupport 尾差补齐

- 剩余 9 条规则都在上游 `ShellCheck.Checks.ShellSupport` 里有明确实现，可逐条移植：
  - `SC2001`、`SC2025`、`SC2051`、`SC2079`
  - `SC2175`、`SC2180`
  - `SC2325`、`SC2326`、`SC2332`
- 建议顺序：
  1. 先补 `SC2051`、`SC2079`、`SC2180` 这类更常见的 bash 语义警告
  2. 再补 `SC2325`、`SC2326`、`SC2332` 这种 pipeline/`!` 规则
  3. 最后补风格类的 `SC2001`、`SC2025`、`SC2175`

### P0/P1: Analytics 按批次推进

- 不建议一次性硬抄 `171` 个规则；建议按风险和用户价值拆 4 批。

#### Batch A: 高频 quoting / splitting / unused-state

- 代表规则：
  - `SC2086`
  - `SC2034`
  - `SC2016`
  - `SC2050`
  - `SC2088`
  - `SC2140`
  - `SC2153`
  - `SC2258`
  - `SC2298`
- 代表上游检查族：
  - `checkInexplicablyUnquoted`
  - `checkConstantIfs`
  - `checkLiteralBreakingTest`
  - `checkSingleQuotedVariables`
  - `checkUnquotedParameterExpansionPattern`
  - `checkPlusEqualsNumber`

#### Batch B: read / find / pipeline / status 语义

- 代表规则：
  - `SC2013`
  - `SC2038`
  - `SC2067`
  - `SC2181`
  - `SC2187`
  - `SC2208`
  - `SC2209`
  - `SC2314`
  - `SC2315`
- 代表上游检查族：
  - `checkFindExec`
  - `checkWhileReadPitfalls`
  - `checkReadWithoutR`
  - `checkPipePitfalls`
  - `checkRedirectedNowhere`
  - `checkPipeToNowhere`

#### Batch C: arithmetic / condition / test pitfalls

- 代表规则：
  - `SC2004`
  - `SC2070`-`SC2084`
  - `SC2116`
  - `SC2233`-`SC2237`
  - `SC2243`
  - `SC2245`-`SC2247`
- 代表上游检查族：
  - `checkNumberComparisons`
  - `checkArithmeticDeref`
  - `checkArithmeticBadOctal`
  - `checkValidCondOps`
  - `checkBadTestAndOr`
  - `checkSecondArgIsComparison`
  - `checkComparisonWithLeadingX`
  - `checkUnaryTestA`

#### Batch D: command reasoning / path / env / shell behavior

- 代表规则：
  - `SC2009`-`SC2017`
  - `SC2025`-`SC2035`
  - `SC2054`-`SC2058`
  - `SC2118`-`SC2127`
  - `SC2270`-`SC2285`
  - `SC2309`
  - `SC2336`
- 代表上游检查族：
  - `checkPS1Assignments`
  - `checkOverridingPath`
  - `checkSuspiciousIFS`
  - `checkGlobsAsOptions`
  - `checkCpLegacyR`
  - `checkBlatantRecursion`
  - `checkBatsTestDoesNotUseNegation`
  - `checkUnnecessaryParens`

### P1: Span / fix fidelity

- spot check 已说明，当前不仅有“缺规则”，也有“已命中规则但 span 不准”的问题。
- 先补差分测试覆盖这几类嵌套场景：
  - brace expansion 内变量
  - parameter expansion pattern/replacement
  - command substitution + redirection 嵌套
- 重点排查：
  - `parser.Span` 构造
  - `semantics/indexed_ast.mbt` 的 parent/child 绑定
  - `fixer` 在嵌套 token 上的 replacement 定位

### P2: Parser 收尾

- parser 不是当前最大缺口，但建议做一轮系统 differential：
  - 对齐 `ShellCheck.Parser` 的 property corpus 命名样例
  - 扫一遍当前 `parser/shellcheck_compat_test.mbt` 与上游 prop 名列表的未覆盖项
  - 优先关注 shebang / shell directive / source resolution / diagnostic span
- 这一阶段目标不是先加新语法，而是先把“已有语法的诊断位置和恢复行为”压实。

## 建议执行顺序

1. 先做 differential harness，把差异固化成测试。
2. 收掉 Commands 的 5 个明确缺口。
3. 收掉 ShellSupport 的 9 个明确缺口。
4. Analytics 按 4 个 batch 分批推进，每批只处理一类问题。
5. 最后做 span/fix fidelity 和 parser differential 收尾。

## 验收口径

- 以 `shellcheck 0.11.0` 的 `json` 输出为基准。
- 忽略 CLI exit code。
- 重点比对：
  - `code`
  - `severity`
  - `message` 主体
  - `line/column/span`
  - `fix` 是否存在，以及 replacement 数量/位置
