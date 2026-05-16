# bashcheck 与 ../shellcheck 规则对齐计划

## 最新进展（2026-05-16）

本轮继续从“维护已有 regression / fix 元数据锁定”里挑选 formatter 端尚未覆盖的 replacement 输出形状：

- `SC2292`
- `SC2336`

对应落点与对齐证据：

- `formatter/formatter_test.mbt`
- `../shellcheck/src/ShellCheck/Analytics.hs` 中 `checkRequireDoubleBracket` 的 `replaceStart` / `replaceEnd` fix 逻辑，以及 `checkCpLegacyR` 的 `replaceToken` fix 逻辑

说明：

- 补上 formatter `json1` 对 optional `SC2292` 双 replacement 的字段形状断言，锁定 `line` / `column` / `endColumn`、replacement 文本、precedence 和 `InsertAfter` / `InsertBefore` 锚点。
- 补上 formatter `json1` 对 `SC2336` 单 token replacement 的字段形状断言，锁定 `cp -r` 到 `cp -R` 的 replacement span、文本、precedence 和 `InsertAfter` 锚点，并同时覆盖 diff 应用结果。

## 最新进展（2026-05-16）

本轮继续从“维护已有 regression / fix 元数据锁定”挑选 command 侧已有 fix、但本地仍只锁应用结果的规则：

- `SC2162`

对应落点与对齐证据：

- `checks/commands_test.mbt`
- `formatter/formatter_test.mbt`
- `../shellcheck/src/ShellCheck/Analytics.hs` 中 `checkReadWithoutR` 的诊断落点；本仓库保留在 `read` 命令词尾插入 ` -r` 的本地 fix，并按 ShellCheck JSON replacement 字段形状锁定输出

说明：

- 补强 `SC2162` 的 command fix 回归，从“只看应用结果”扩展为同时锁定 replacement 起止位置、文本、precedence 和 `InsertBefore` 锚点。
- 补上 formatter JSON 对 `SC2162` 单 replacement 的字段形状断言，覆盖 `beforeStart`、line/column、precedence 和 replacement 文本。

## 最新进展（2026-05-16）

本轮继续从“维护已有 regression / fix 元数据锁定”挑选一组早期已实现、但本地仍可对齐 upstream replacement 形状的高频规则：

- `SC2006`
- `SC2086`
- `SC2095`

对应落点与对齐证据：

- `checks/analytics.mbt`
- `checks/analytics_test.mbt`
- `checks/analytics_batch_a_test.mbt`
- `checks/analytics_batch_k_test.mbt`
- `formatter/formatter_test.mbt`
- `../shellcheck/src/ShellCheck/Analytics.hs` 中 `checkBackticks` / `addDoubleQuotesAround` / `checkMuncher` 的 `replaceStart` / `replaceEnd` fix 逻辑

说明：

- 将 `SC2006` 的 legacy backtick fix 从整词替换改为与 upstream 一样的首尾 backtick replacement，锁定每个 replacement 的起止位置、文本、precedence、`InsertAfter` / `InsertBefore` 锚点和实际应用结果。
- 补强 `SC2086` 与 `SC2095` 既有 fix 回归，从“只看应用结果”扩展为同时锁定 replacement 起止位置、文本、precedence 和插入方向。

## 最新进展（2026-05-16）

本轮继续从已收口阶段里的“维护已有 regression / fix 元数据锁定”挑选一组 upstream 已有 `fixWith` 形状、但本地仍可补强的规则：

- `SC2164`
- `SC2191`
- `SC2251`
- `SC2265`
- `SC2266`

对应落点与对齐证据：

- `checks/analytics_batch_d.mbt`
- `checks/analytics_batch_d_test.mbt`
- `checks/analytics_batch_m_test.mbt`
- `checks/analytics_batch_q_test.mbt`
- `../shellcheck/src/ShellCheck/Analytics.hs` 中 `checkUncheckedCdPushdPopd` / `checkArrayAssignmentIndices` / `checkUselessBang` / `checkTestArgumentSplitting` 的 `replaceEnd` / `replaceStart` / `surroundWith` fix 逻辑

说明：

- 为 `SC2164` 补齐与 upstream 一样在未检查 `cd` / `pushd` / `popd` 命令尾部追加 ` || exit` 的 fix，并锁定 replacement span、文本、precedence、`InsertBefore` 锚点和实际应用结果。
- 补强 `SC2191`、`SC2251`、`SC2265`、`SC2266` 既有 fix 回归，从“只看应用结果”扩展为同时锁定 replacement 起止位置、文本、precedence 和插入方向。

## 最新进展（2026-05-16）

本轮继续从阶段 E 收口后的“维护已有 regression”里挑选已实现、已有 upstream fix 形状、但适合补独立 replacement 锁定的规则：

- `SC2277`
- `SC2281`
- `SC2292`
- `SC2295`
- `SC2336`

对应落点与对齐证据：

- `checks/analytics_optional.mbt`
- `checks/analytics_test.mbt`
- `checks/analytics_batch_i_test.mbt`
- `checks/analytics_batch_p_test.mbt`
- `checks/analytics_batch_s_test.mbt`
- `../shellcheck/src/ShellCheck/Analytics.hs` 中 `checkEqualsInCommand` / `checkRequireDoubleBracket` / `checkUnquotedParameterExpansionPattern` / `checkCpRecursive` 的 `replaceStart` / `replaceEnd` / `replaceToken` / `surroundWith` fix 逻辑

说明：

- 补齐 `SC2292` 的简单 `[ ]` 到 `[[ ]]` fix，实现与 upstream 一样的开头 `[` 插入和结尾 `]` 插入。
- 锁定 `$0` 赋值替换为 `BASH_ARGV0`、左侧 `$` / `${}` 删除、`${..}` pattern 内 expansion 单独加引号、`cp -r` 替换为 `cp -R` 的 replacement 起止位置、replacement 文本、precedence、`InsertAfter` / `InsertBefore` 锚点和实际应用结果。

## 最新进展（2026-05-16）

本轮继续从阶段 E 收口后的“维护已有 regression”里挑选已实现、已有 upstream baseline、但适合补独立 fix replacement 锁定的 `Analytics.hs` 规则：

- `SC2314`
- `SC2321`
- `SC2322`
- `SC2323`
- `SC2331`

对应落点与对齐证据：

- `checks/analytics_batch_n_test.mbt`
- `checks/analytics_batch_l_test.mbt`
- `checks/analytics_batch_r_test.mbt`
- `../shellcheck/src/ShellCheck/Analytics.hs` 中 `checkBatsTestDoesNotUseNegation` / `checkUnnecessaryArithmeticExpansion` / `checkUnnecessaryParens` / `checkUnaryTestA` 的 `replaceStart` / `replaceEnd` / `replaceToken` fix 逻辑

说明：

- 补齐 Bats `run ` 插入、数组下标 `$((...))` wrapper 删除、算术双层括号删除、legacy `-a` 替换为 `-e` 的 replacement 起止位置、replacement 文本、precedence、`InsertAfter` / `InsertBefore` 锚点和实际应用结果锁定。

## 最新进展（2026-05-16）

本轮继续从阶段 E 收口后的“维护已有 regression”里挑选已有实现、已有 fix 应用测试，但 replacement 元数据仍适合独立锁定的 `Analytics.hs` 规则：

- `SC2258`
- `SC2264`
- `SC2268`

对应落点与对齐证据：

- `checks/analytics_batch_a_test.mbt`
- `checks/analytics_batch_o_test.mbt`
- `checks/analytics_batch_j_test.mbt`
- `../shellcheck/src/ShellCheck/Analytics.hs` 中 `checkForInQuoted` / `checkBlatantRecursion` / `checkComparisonWithLeadingX` 的 `replaceEnd` / `replaceStart` fix 逻辑

说明：

- 补齐 trailing comma 删除、递归函数 `command ` 前缀插入、leading `x` 比较删除的 replacement 起止位置、replacement 文本、precedence、`InsertBefore` / `InsertAfter` 锚点和实际应用结果锁定。

## 最新进展（2026-05-16）

本轮继续从阶段 E 收口后的“维护已有 regression”里挑选 optional `Analytics.hs` 规则，补齐与 upstream fix replacement 形状相关的锁定：

- `SC2248`
- `SC2250`

对应落点与对齐证据：

- `checks/util.mbt`
- `checks/analytics_optional.mbt`
- `checks/analytics_test.mbt`
- `../shellcheck/src/ShellCheck/Analytics.hs` 中 `addDoubleQuotesAround` / `checkVariableBraces` 的 `replaceStart` + `replaceEnd` fix 逻辑

说明：

- 将 `SC2248` 的 quote fix 和 `SC2250` 的 brace fix 对齐为 ShellCheck 风格的分段 replacement，并锁定 replacement 起止位置、replacement 文本、precedence、`InsertAfter` / `InsertBefore` 锚点和实际应用结果。

## 最新进展（2026-05-16）

本轮继续从阶段 E 收口后的“维护已有 regression”里挑选已经实现、已有 baseline、但 fix 元数据仍适合独立锁定的 `Analytics.hs` 规则：

- `SC2247`
- `SC2256`

对应落点与对齐证据：

- `checks/analytics_test.mbt`
- `checks/analytics_batch_j_test.mbt`
- `../shellcheck/src/ShellCheck/Analytics.hs` 中 `checkDollarQuoteParen` / `checkTranslatedStringVariable` 的 `replaceStart ... 2 "\"$"` 逻辑

说明：

- 补齐 quote-swap fix 的 replacement 起止位置、replacement 文本、precedence、`InsertAfter` 锚点和实际应用结果回归，避免后续维护时只锁诊断、不锁 fix 形状。

## 最新进展（2026-05-16）

本轮继续从阶段 E 的“维护已有 regression”里挑选与现有 `SC2243` 相邻、同属 optional `Analytics.hs` nullary condition fix 的规则：

- `SC2244`

对应落点与对齐证据：

- `checks/analytics_optional.mbt`
- `checks/analytics_test.mbt`
- `../shellcheck/src/ShellCheck/Analytics.hs` 的 `styleWithFix id 2244 ... replaceStart ... "-n "` 逻辑

说明：

- 对齐 `SC2244` 的 fix replacement 元数据，使其与 upstream 一样在原始 nullary word 起点用 `InsertAfter` 插入 `-n `，并锁定 precedence、replacement span 与实际应用结果。

## 最新进展（2026-05-16）

本轮继续从阶段 E 的“维护已有 regression”里挑选已有 upstream baseline、但适合补独立 fix 锁定的 optional `Analytics.hs` 规则：

- `SC2243`

对应落点与对齐证据：

- `checks/analytics_test.mbt`
- `../shellcheck/src/ShellCheck/Analytics.hs` 的 `styleWithFix id 2243 ... replaceStart ... "-n "` 逻辑

说明：

- 在已有动态 JSON baseline 和 `checker` 端到端 span / severity / message regression 之外，补上本地 fix 应用回归，锁定 `[[ $(cmd) ]]` 自动修复为 `[[ -n $(cmd) ]]` 的 replacement 位置、插入方向和 precedence。

## 最新进展（2026-05-16）

本轮继续从阶段 E 的“维护已有 regression”里挑选已经有 upstream baseline、但适合补独立 `checker` 精确锁定的 `Analytics.hs` 规则：

- `SC2158`
- `SC2159`
- `SC2160`
- `SC2161`
- `SC2165`
- `SC2167`
- `SC2272`
- `SC2276`

对应落点与对齐证据：

- `checker/analytics_stage_e_compat_regression_test.mbt`

说明：

- 对照 `../shellcheck/src/ShellCheck/Analytics.hs` 中的 constant nullary、loop variable override、assignment-shaped command 诊断文案，补齐 `checker` 层的 span / severity / message regression。

## 最新进展（2026-05-16）

本轮从阶段 E 的“维护已有 regression”尾项里挑了一批已经有 upstream baseline、但缺少独立 `checker` 端到端锁定的规则补证据：

- `SC2001`
- `SC2016`
- `SC2025`
- `SC2028`
- `SC2051`
- `SC2088`
- `SC2155`
- `SC2172`
- `SC2173`
- `SC2175`
- `SC2180`
- `SC2258`
- `SC2325`
- `SC2326`

对应落点与对齐证据：

- `checker/analytics_stage_e_compat_regression_test.mbt`
- `checker/commands_compat_regression_test.mbt`
- `checker/shell_support_compat_regression_test.mbt`

说明：

- 这批规则此前已经在 `compat/json_diff_baseline_test.mbt` 中通过动态 JSON baseline 对齐 `../shellcheck`；本轮补的是 `checker` 层的显式 span / severity / message regression，避免后续维护时只依赖动态 baseline。

## 最新进展（2026-04-19）

本轮推进了阶段 E 的维护回归，为已有 upstream baseline 的 `commands` / `shell-support` 规则补上独立的 `checker` 端到端锁定：

- `SC2306`
- `SC3028`
- `SC3029`
- `SC3036`
- `SC3039`
- `SC3041`
- `SC3043`
- `SC3044`
- `SC3061`

对应落点与对齐证据：

- `checker/commands_compat_regression_test.mbt`
- `checker/shell_support_compat_regression_test.mbt`

说明：

- 这批规则此前已经有 `compat/` 动态 baseline；本轮补的是 `checker` 层的显式 span / severity / message regression，便于后续维护阶段直接锁端到端输出。

## 最新进展（2026-04-19）

本轮推进了阶段 B 最后的 condition parser / bad test 逻辑操作符缺口，对齐补上了：

- `SC2107`
- `SC2108`
- `SC2109`
- `SC2110`

对应落点与对齐证据：

- `parser/ast.mbt`（为条件逻辑操作符补充独立 AST 节点，保留 operator text/span）
- `parser/parser.mbt`
- `parser/parser_test.mbt`
- `parser/shellcheck_compat_test.mbt`
- `checks/analytics_batch_g.mbt`
- `checks/analytics_batch_g_wbtest.mbt`
- `compat/analytics_stage_b_diff_baseline_test.mbt`
- `checker/analytics_stage_b_compat_regression_test.mbt`
- `parser/pkg.generated.mbti`

## 最新进展（2026-04-19）

本轮推进了阶段 C 剩余的执行模型 / shell feature / `set -e` 缺口，对齐补上了：

- `SC2127`
- `SC2251`
- `SC2257`
- `SC2265`
- `SC2266`

对应落点与对齐证据：

- `checks/analytics_batch_d.mbt`
- `checks/analytics_batch_q.mbt`
- `checks/analytics_batch_d_test.mbt`
- `checks/analytics_batch_q_test.mbt`
- `compat/analytics_stage_c_diff_baseline_test.mbt`
- `checker/analytics_stage_c_compat_regression_test.mbt`

## 最新进展（2026-04-19）

本轮推进了阶段 C 第一批执行模型 / 重定向 / 条件风格缺口，对齐补上了：

- `SC2118`
- `SC2129`
- `SC2143`

对应落点与对齐证据：

- `checks/analytics_batch_d.mbt`
- `checks/analytics_batch_q.mbt`
- `checks/analytics_batch_d_test.mbt`
- `checks/analytics_batch_q_test.mbt`
- `compat/analytics_stage_c_diff_baseline_test.mbt`
- `checker/analytics_stage_c_compat_regression_test.mbt`

## 最新进展（2026-04-19）

本轮推进了阶段 E 剩余的 optional / command-name baseline 补证据，对齐补上了：

- `SC2237`
- `SC2243`
- `SC2289`
- `SC2310`
- `SC2335`

对应落点与对齐证据：

- `checks/analytics_optional.mbt`（把 `SC2237` / `SC2335` 的 span、`SC2243` 的 fix 元数据校正到与 upstream 一致）
- `compat/analytics_stage_e_diff_baseline_test.mbt`
- `checker/analytics_stage_e_compat_regression_test.mbt`

## 最新进展（2026-04-19）

本轮推进了阶段 E 的 `analytics` / `commands` / `shell-support` baseline 补证据，对齐补上了：

- `SC2158`
- `SC2159`
- `SC2160`
- `SC2161`
- `SC2165`
- `SC2167`
- `SC2272`
- `SC2276`
- `SC2306`
- `SC3028`
- `SC3029`
- `SC3036`
- `SC3039`
- `SC3041`
- `SC3043`
- `SC3044`
- `SC3061`

对应落点与对齐证据：

- `compat/analytics_stage_e_diff_baseline_test.mbt`
- `compat/commands_diff_baseline_test.mbt`
- `compat/shell_support_diff_baseline_test.mbt`

## 最新进展（2026-04-18）

本轮推进了阶段 B / C / D 的 loop keyword / stderr redirect / shebang 参数缺口，对齐补上了：

- `SC2069`
- `SC2096`
- `SC2104`
- `SC2105`
- `SC2106`

对应落点与对齐证据：

- `checks/analytics_batch_d.mbt`
- `checks/analytics_batch_q.mbt`
- `checks/analytics_batch_d_test.mbt`
- `checks/analytics_batch_q_test.mbt`
- `compat/analytics_stage_b_diff_baseline_test.mbt`
- `compat/analytics_stage_c_diff_baseline_test.mbt`
- `compat/analytics_stage_d_diff_baseline_test.mbt`
- `checker/analytics_stage_b_compat_regression_test.mbt`
- `checker/analytics_stage_c_compat_regression_test.mbt`
- `checker/analytics_stage_d_compat_regression_test.mbt`

本轮推进了阶段 B / C 的字符类 / 比较 / `cd` 回退缺口，对齐补上了：

- `SC2101`
- `SC2102`
- `SC2103`
- `SC2171`
- `SC2193`

对应落点与对齐证据：

- `checks/analytics_batch_a.mbt`
- `checks/analytics_batch_b.mbt`
- `checks/analytics_batch_d.mbt`
- `checks/analytics_batch_m.mbt`（把 pseudo-glob 重建精度补到能识别 `*.png` vs `[a-z]` 这类 `SC2193` 场景）
- `checks/analytics_batch_a_test.mbt`
- `checks/analytics_batch_b_test.mbt`
- `checks/analytics_batch_d_test.mbt`
- `compat/analytics_stage_b_diff_baseline_test.mbt`
- `compat/analytics_stage_c_diff_baseline_test.mbt`
- `checker/analytics_stage_b_compat_regression_test.mbt`
- `checker/analytics_stage_c_compat_regression_test.mbt`

本轮推进了阶段 D 的数组 / 默认赋值 / subshell 样式缺口，对齐补上了：

- `SC2082`
- `SC2124`
- `SC2125`
- `SC2223`
- `SC2233`
- `SC2234`
- `SC2235`

对应落点与对齐证据：

- `checks/analytics_batch_w.mbt`
- `checks/analytics_batch_w_test.mbt`
- `checks/analytics_batch_a.mbt`（让 `SC2223` 正确取代同位置的 `SC2086`）
- `compat/analytics_stage_d_diff_baseline_test.mbt`
- `checker/analytics_stage_d_compat_regression_test.mbt`
- `checker/compat_regression_test.mbt`（把 `SC2125` 纳入既有 broad regression）

本轮推进了阶段 B / C 的条件操作数缺口，对齐补上了：

- `SC2144`
- `SC2198`
- `SC2199`
- `SC2200`
- `SC2201`
- `SC2202`
- `SC2203`
- `SC2208`
- `SC2245`
- `SC2255`

对应落点与对齐证据：

- `checks/analytics_batch_g.mbt`
- `checks/analytics_batch_g_condition_test.mbt`
- `compat/condition_operand_diff_baseline_test.mbt`
- `checker/condition_operand_compat_regression_test.mbt`

本轮推进了阶段 E 的 `analytics` 条件 / 样式 baseline，对齐补上了：

- `SC2004`
- `SC2017`
- `SC2070`
- `SC2074`
- `SC2075`
- `SC2077`

对应落点与对齐证据：

- `checks/analytics_batch_g.mbt`
- `checks/analytics_batch_e.mbt`
- `checks/analytics.mbt`
- `compat/analytics_stage_e_diff_baseline_test.mbt`
- `checker/analytics_stage_e_compat_regression_test.mbt`

本轮推进了阶段 E 第一批 `commands` upstream baseline，对齐补上了：

- `SC2059`
- `SC2060`
- `SC2063`
- `SC2152`
- `SC2241`

对应落点与对齐证据：

- `compat/commands_diff_baseline_test.mbt`
- `checker/commands_compat_regression_test.mbt`

本轮推进了阶段 E 第二批 `commands` upstream baseline，对齐补上了：

- `SC2020`
- `SC2021`
- `SC2227`
- `SC2305`
- `SC2307`
- `SC2308`

对应落点与对齐证据：

- `compat/commands_diff_baseline_test.mbt`
- `checker/commands_compat_regression_test.mbt`

本轮推进了阶段 D 的数组赋值缺口，补上了：

- `SC2190`
- `SC2191`
- `SC2192`

对应落点与对齐证据：

- `checks/analytics_batch_m.mbt`
- `checks/analytics_batch_m_test.mbt`
- `compat/json_diff_baseline_test.mbt`
- `checker/compat_regression_test.mbt`

本轮推进了阶段 B / C / D 的一批低耦合 `Analytics.hs` 缺口，补上了：

- `SC2054`
- `SC2111`
- `SC2112`
- `SC2113`
- `SC2123`

对应落点与对齐证据：

- `checks/analytics_batch_d.mbt`
- `checks/analytics_batch_h.mbt`
- `checks/analytics_batch_m.mbt`
- `checks/analytics_batch_d_test.mbt`
- `checks/analytics_batch_h_test.mbt`
- `checks/analytics_batch_m_test.mbt`
- `compat/json_diff_baseline_test.mbt`
- `checker/compat_regression_test.mbt`
- `parser/parser_test.mbt`（补一条本仓库特有 AST 形态回归，锁住 `a=([a]=b,[c]=d,[e]=f)` 被 parser 收成单个 element 的现状）

本轮完成了阶段 A 剩余的 subshell 赋值缺口：

- `SC2030`
- `SC2031`

对应落点与对齐证据：

- `checks/analytics_batch_v.mbt`
- `checks/analytics_batch_v_test.mbt`
- `compat/subshell_diff_baseline_test.mbt`
- `checker/subshell_compat_regression_test.mbt`
- `checks/control_flow.mbt`（抑制与 `SC2031` 重叠的 `SC2154` 误报）

本轮继续对齐阶段 A 的高频 `Analytics.hs` 缺口，补上了：

- `SC2089`
- `SC2090`
- `SC2026`
- `SC2027`
- `SC2116`

对应落点与对齐证据：

- `checks/analytics_batch_a.mbt`
- `checks/analytics_batch_t.mbt`
- `checks/analytics_batch_a_test.mbt`
- `checks/analytics_batch_t_test.mbt`
- `compat/json_diff_baseline_test.mbt`
- `checker/compat_regression_test.mbt`

此前已完成并落到 `checks/analytics_batch_u.mbt` 的规则：

- `SC2009`
- `SC2010`
- `SC2011`
- `SC2012`
- `SC2013`
- `SC2014`
- `SC2038`
- `SC2067`
- `SC2126`

对应已补的对齐证据：

- `checks/analytics_batch_u_test.mbt`
- `compat/json_diff_baseline_test.mbt`
- `checker/compat_regression_test.mbt`

此前已完成并落到 `checks/analytics_batch_t.mbt` 的规则：

- `SC2007`
- `SC2084`
- `SC2091`
- `SC2092`
- `SC2093`
- `SC2094`
- `SC2116`
- `SC2209`

对应已补的对齐证据：

- `checks/analytics_batch_t_test.mbt`
- `compat/json_diff_baseline_test.mbt`
- `checker/compat_regression_test.mbt`

## 范围与方法

本次对齐分析以 `../shellcheck` 的以下源码为基准：

- `src/ShellCheck/Parser.hs`
- `src/ShellCheck/Checker.hs`
- `src/ShellCheck/Analytics.hs`
- `src/ShellCheck/Checks/Commands.hs`
- `src/ShellCheck/Checks/ShellSupport.hs`

对比方式分两层：

1. **硬缺口**：upstream 规则号在当前仓库代码树里完全没有落地。
2. **二级风险**：规则已经实现，但还没有显式的 ShellCheck 对齐基线或 JSON diff 用例。

## 结论摘要

- parser / checker / CLI / formatter 的对齐工作已经有比较完整的基线：
  - `compat/parser_condition_diff_baseline_test.mbt`
  - `compat/parser_boundary_diff_baseline_test.mbt`
  - `compat/rule_diff_baseline_test.mbt`
  - `compat/json_diff_baseline_test.mbt`
- `compat/cli_diff_baseline_test.mbt`
- `checker/shellcheck_compat_wbtest.mbt`
- `parser/*shellcheck*_test.mbt`
- 从规则号差集看，**当前没有新的 10xx/11xx parser 规则硬缺口，也没有新的 30xx shell-support 规则硬缺口**。
- 此前剩余真正未落地的规则，主要集中在 **ShellCheck 的 `Analytics.hs` 家族**。
- 去掉 upstream 注释里的 `#1181` 这类非规则编号后，**当前真实规则硬缺口已经清空**。
- 此前缺少显式 upstream baseline 的二级风险规则已经清空；当前剩余工作主要是维护已有 compat regression，并在后续新增规则时继续沿用同一套基线策略。

## 硬缺口清单

### 1. 条件表达式 / 数值比较家族

- 已清空（`SC2107-2110` 已补齐，且 parser 现已能保留这类 malformed `[ .. ]` / `[[ .. ]]` 输入形态，供 `checks/` 层做 ShellCheck 风格诊断）

### 2. 执行模型 / 环境 / set -e 家族

- 已清空（`SC2069` / `SC2118` / `SC2127` / `SC2129` / `SC2143` / `SC2251` / `SC2257` / `SC2265` / `SC2266` 已补齐）

### 3. shebang / entry 家族

- 已清空（`SC2096` 已补齐）

### 4. 数组 / case / 样式化重写家族

- 已清空（`SC2233-2235` 已补齐）

## 二级风险：已实现但没有显式 upstream baseline 的规则

这批规则已经清空。此前缺少显式 upstream baseline 的：

`2237 2243 2289 2310 2335`

已在本轮进展中移出该列表、并补齐 upstream baseline 的规则：

`2020 2021 2025 2158 2159 2160 2161 2165 2167 2175 2180 2227 2237 2243 2258 2272 2276 2289 2305 2306 2307 2308 2310 2325 2326 2335 3028 3029 3036 3039 3041 3043 3044 3061`

这批规则的风险不是“缺实现”，而是：

- 位置、严重级别、文案是否和 upstream 一致还没有被锁定
- fixer 文本是否与 ShellCheck 风格一致还没有回归保护
- 某些规则可能只有内部单测，没有 end-to-end `checker` 层校验

## 分阶段对齐计划

### 阶段 A：先补剩余硬缺口中的高频 Analytics 规则

目标：

- 先把最常见、最容易被用户感知的缺口补上
- 优先做那些能直接进 `compat/json_diff_baseline_test.mbt` 的规则

建议范围：

- 本阶段高频缺口已清空

本轮已完成：

- `2030-2031`
- `2026-2027`
- `2007`
- `2009-2014`
- `2054`
- `2038`
- `2067`
- `2084`
- `2089-2090`
- `2111-2113`
- `2116`
- `2123`
- `2091-2094`
- `2126`
- `2209`

阶段 A 剩余建议范围：

- 暂无；可以转入阶段 B / C / D 的剩余缺口

落点建议：

- 继续沿用 `checks/analytics_batch_*` 的分批结构
- 不再把逻辑堆回 `checks/analytics.mbt`
- 若现有 batch 不再自然贴合，继续新增独立 batch（例如本轮的 `analytics_batch_v.mbt`）

验收：

- 每个规则至少有一条 `compat/json_diff_baseline_test.mbt` 用例
- 对有修复建议的规则，再补 `checker/compat_regression_test.mbt` 精确断言 span / severity / message / fix

### 阶段 B：补条件表达式和测试语义缺口

目标：

- 集中清掉最容易产生 false positive / false negative 的 test 语义差异

建议范围：

- `2104-2110`

本轮已完成：

- `2104-2106`
- `2101`
- `2102`
- `2103`
- `2107-2110`
- `2171`
- `2193`

阶段 B 剩余建议范围：

- 暂无；阶段 B 已收口

额外备注：

- 本轮已经先补 parser AST，再补 `checks` / `checker` / `compat` 对齐，因此这批 malformed test 形态现在既能保留，又有 end-to-end 回归保护。

落点建议：

- 优先扩展现有条件相关 batch：
  - `checks/analytics_batch_b.mbt`
  - `checks/analytics_batch_e.mbt`
  - `checks/analytics_batch_g.mbt`
- 如果一个 batch 的语义跨度已经过大，再拆新 batch

验收：

- 先补 upstream 对应最小复现样例
- 再补 1-2 个本仓库特有 AST 形态的 regression case，防止 parser/semantics 适配层引入偏差

### 阶段 C：补执行模型、环境和 set -e 相关规则

目标：

- 把目前最像“checker 行为差异”的 Analytics 缺口补齐

建议范围：

- `2127`
- `2251`
- `2257`
- `2265`
- `2266`

本轮已完成：

- `2069`
- `2118`
- `2129`
- `2143`
- `2127`
- `2251`
- `2257`
- `2265`
- `2266`

阶段 C 剩余建议范围：

- 暂无；阶段 C 已收口

落点建议：

- 执行流和副作用相关逻辑优先复用：
  - `cfg/`
  - `semantics/`
  - `checks/analytics_batch_d.mbt`
  - `checks/analytics_batch_q.mbt`

验收：

- `compat/json_diff_baseline_test.mbt` 覆盖 ShellCheck 输出
- `checker/compat_regression_test.mbt` 补端到端排序和 fix 文本

### 阶段 D：补数组 / case / 样式规则

目标：

- 补完剩余相对分散、但实现成本较低的尾部规则

建议范围：

- `2096`

本轮已完成：

- `2096`
- `2082`
- `2124-2125`
- `2223`
- `2233-2235`

落点建议：

- 阶段 D 的剩余硬缺口已清空；后续只需要维护既有 regression，不必继续往数组批次塞 shebang / entry 逻辑

验收：

- 对每个规则至少有 1 条纯对齐用例
- 对带 fix 的规则至少有 1 条 fix regression

### 阶段 E：补齐“已实现但未建 upstream baseline”的剩余规则

目标：

- 把“实现存在但对齐证据不足”的规则全部纳入兼容回归

执行顺序建议：

1. 非 portability baseline 已清空
2. portability baseline 也已清空；后续只需维护回归

当前进度：

- `commands` 第一批里，`2028 2155 2172 2173 2059 2060 2063 2152 2241` 已补齐 upstream baseline
- `commands` 第二批里，`2020 2021 2227 2305 2306 2307 2308` 已补齐 upstream baseline
- `analytics` 第二批里，`2001 2004 2016 2017 2051 2070 2074 2075 2077 2088 2158 2159 2160 2161 2165 2167 2237 2243 2272 2276 2289 2310 2335` 已补齐 upstream baseline
- `shell-support` / portability 第一批里，`2025 2175 2180 2325 2326` 已补齐 upstream baseline
- `shell-support` / portability 第二批里，`3028 3029 3036 3039 3041 3043 3044 3061` 已补齐 upstream baseline
- `analytics` 兼容基线补证据里，`2258` 已补齐 upstream baseline
- `checker` 端到端维护回归里，`2001 2016 2025 2028 2051 2088 2155 2158 2159 2160 2161 2165 2167 2172 2173 2175 2180 2258 2272 2276 2325 2326` 已补齐显式 span / severity / message 锁定
- `fix` 维护回归里，`2006 2086 2095 2164 2191 2243 2244 2247 2248 2250 2251 2256 2258 2264 2265 2266 2268 2314 2321 2322 2323 2331` 已补齐本地 replacement 元数据与应用结果锁定
- 当前还剩 `0` 条二级风险规则，其中：
  - 非 portability `0` 条
  - `shell-support` / portability `0` 条
- 阶段 E 已收口；当前计划里的阶段 B-E 硬缺口也已收口，后续以维护 regression 为主

验收：

- 这些规则全部在 `compat/` 或 `checker/compat_regression_test.mbt` 里能找到显式编号
- 不再依赖“只在内部单测里出现过”这种弱证据

## 推荐实施顺序

1. 阶段 A
2. 阶段 B
3. 阶段 C
4. 阶段 D
5. 阶段 E

原因：

- A/B/C 解决的是“用户直接看得到的行为缺口”
- D 是尾部收口
- E 是把当前已有实现补成“可持续维护的兼容基线”

## 每个阶段的统一交付标准

每一阶段结束时，都应做到：

1. 新规则进入 `checks/` 的明确 batch，不把逻辑散落到大文件里。
2. 至少补一条 `compat/json_diff_baseline_test.mbt` 或固定 baseline 对齐用例。
3. 对有 fix 的规则，补 `checker/compat_regression_test.mbt`；无 fix 但需要锁位置/文案时，可新增独立 regression 文件。
4. 跑最小必要验证：
   - `moon test compat`
   - `moon test checker`
   - `moon test checks`
5. 阶段收尾时再执行：
   - `moon info`
   - `moon fmt`

## 备注

- 这份计划里，`1181` 没算规则，它只是 upstream `Checker.hs` 注释里引用的 issue 编号。
- 当前仓库已经把不少 phase 0-5 的对齐工作固化在 `compat/` 里；后续建议继续沿用这个思路，不要只补内部单测，不补 upstream 基线。
