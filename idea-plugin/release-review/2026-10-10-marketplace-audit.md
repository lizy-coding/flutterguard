# JetBrains Marketplace 发布前审查 — 2026-10-10

结论：**NO-GO，当前候选包不可直接提交。**

审查对象为当前工作区的 IDEA 插件、明确选中的 CLI 执行入口、分发脚本及实际 ZIP。
这是发布材料与技术合规检查，不是 JetBrains 审批结果。未登录、上传、发布或接受开发者协议。

## 产物证据

- 源码基点：`fb86f4ffa322bb0dbe69748c5c594296bf44657d`；存在未提交的 CLI/IDE 实现。
- 候选包：`idea-plugin/build/distributions/flutterguard-idea-0.7.1.zip`。
- SHA-256：`3eac1d95edf5e5176807aebbe59611f9bbc0d60c7420484934e827d8959f49f1`；大小：4186514 bytes。
- ID/version：`com.flutterguard` / `0.7.1`。
- 实际声明：`since-build=261`，`until-build=261.*`。
- 实际 native 资源：仅 `flutterguard-darwin-arm64`。
- 当前 `check`、`buildPlugin` 通过；11 项插件测试无失败、无跳过。
- 历史 2024.3 verifier 报告时间为 2026-07-28，不能作为本候选包的验证结果。
- 当前 Plugin Verifier：**PENDING**。针对 IU-261.27258.48 的验证等待插件依赖下载超过 10 分钟，线程诊断确认处于下载阶段；本次取消（exit 130），没有最终 verdict，不标为兼容性通过或不兼容。

## 审查结果

| 项目 | 状态 | 证据与下一步 |
|---|---|---|
| 图标格式 | PASS（格式） | 自有 SVG，40×40；是否拥有全部品牌/素材权利需作者声明 |
| 名称与 ID | PENDING | 名称为 Latin、长度合规；Marketplace 唯一性尚未确认 |
| 英文主说明 | FIXED | 新增完整英文功能、启动步骤、限制及隐私摘要，中文在其后 |
| change-notes | PASS（材料） | 按 0.7.1 本地迭代组织新增、修复、调整；不假称已发布 |
| 许可随包分发 | FIXED（基础） | 加入 META-INF/LICENSE.txt、19 个 runtime 包的原始许可和 Dart SDK 许可 |
| native 第三方许可闭环 | PENDING | 当前库存来自解析后的 runtime 依赖闭包；需对冻结 SDK/构建的 VM 第三方材料继续复核 |
| 源码公开性 | PASS / PENDING | GitHub API 确认仓库 public（HTTP 200）；当前未提交实现尚未绑定到可公开复核的 release revision |
| 读取范围与项目信任 | PENDING | 临时隔离样例确认 include 可读取项目外 Dart 文件；IDE adapter 尚未核验 trusted-project 状态，发布前需明确范围/信任边界 |
| 数据处理说明 | DRAFT | 已准备 privacy.md，记录本地源文件读取、临时二进制、启用开关与本地日志；已补公开邮箱，最终声明及公开 URL 仍待冻结 |
| Native 分发 | FAIL | 缺 macOS x64、Linux x64、Windows x64；经典通用 ZIP 不能靠“缺二进制后提示错误”完成这些宿主的功能验收 |
| Native CI runner | FAIL / WARN | release.yml 使用已退役的 macos-13；macos-14 将于 2026-11-02 退役，需先更新 runner 再生成可验收 native 产物 |
| IDE 兼容声明 | PENDING | 实际包为 261.*，默认构建/默认 verifier 仍指向 2024.3；需冻结申报范围并使用一致的验证目标 |
| 截图材料 | PENDING | 五图已替换为人工截图，无操控图标和试用入口；按实际尺寸保持比例。部分图仍含项目相对主目录路径，配置失败图含 IDEA 拼写提示，最终媒体仍需核对 |
| Vendor 联系资料 | FIXED（元数据） / PENDING（账户） | 已按发布者确认写入 forest.li / zhenyu_li1998@163.com；Vendor profile 与实际身份尚未核对，未验证邮箱可达性 |
| 账户法律步骤 | HUMAN REQUIRED | 本人接受 Developer Agreement、选择 EULA、声明 trader/non-trader；本次未执行 |
| 签名 | NOT VERIFIED | 不把作者签名缺失冒称自动拒审；需明确签名策略并核对最终签名产物 |

## 发布门禁发现与修复

1. `dist/flutterguard-0.7.1-macos-arm64/flutterguard` 与当前 bundled CLI 哈希不同：
   - dist：`0c5cee3b7ae0d2c9aa7b353ea41f6e3ac046f861b3d08acde160379cb2c6b8f1`。
   - bundled：`56ce5e883407505dc12413f2cbfeeba0c34d1e21afcb6398e1cdaa8a9a283ba3`。
   - 两者 version 都为 0.7.1，因此版本字符串不能证明同源。
2. preflight 原先发现缺失后仍会拷贝 dist，可能覆盖当前修复。
   现已改为 native 集合不完整时立即退出；运行验证返回 exit 1，原资源 SHA 保持不变。
3. 原先以目录中第一个 ZIP 为结果，可能选中 0.0.0 等历史包。
   现改为精确 `flutterguard-idea-${VERSION}.zip`。
4. publish 脚本原先将上传成功输出为“published”。现改为上传完成、审批待完成；没有实际执行上传。

上述修复不会使旧 dist 自动可信。冻结源码后，全部 native 目标必须重新构建并记录 source/SDK/hash。

## 建议执行顺序

1. 明确首发 IDE/OS/架构范围。优先沿现有四目标打包结构补齐同源 native 产物；
   若仅发布 macOS arm64，应采用平台支持的原生分发方案并单独核验，不能只改说明。
2. 冻结版本与源码 revision，把完整插件实现公开，并重建全部 native 目标。
3. 核对 Vendor profile、MIT/EULA 选择与隐私声明公开链接；核对 native 第三方 notices。公开 Vendor/隐私联系邮箱已补齐。
4. 准备去标识的 Marketplace media；当前离线图库不等于已经上传的 Marketplace 截图库。
5. 明确 IDE 自动扫描的项目信任/读取范围，并对最终 ZIP 的声明范围跑 Plugin Verifier、功能 smoke 和发布 preflight，记录最终 SHA。
6. 由本人完成账户法律声明，最后再授权上传。上传成功与审核通过分别记录。

## 尚需发布者补齐

- Vendor profile、最终 EULA 与隐私声明公开 URL；公开联系邮箱已于 2026-10-10 由发布者确认。
- 首发 IDE/OS/架构范围及最终版本/source revision。
- 名称/ID 唯一性：本次公开搜索 API 返回 HTTP 400，未据此宣称名称可用；提交前须在 Marketplace 核对。
- 本人接受开发者协议，并按实际身份填写 trader/non-trader，不能由代理替你推定。

## 官方依据（2026-10-10 核对）

- [Marketplace Approval Guidelines v1.3](https://plugins.jetbrains.com/docs/marketplace/jetbrains-marketplace-approval-guidelines.html)
- [Uploading a new plugin](https://plugins.jetbrains.com/docs/marketplace/uploading-a-new-plugin.html)
- [Listing guidance](https://plugins.jetbrains.com/docs/marketplace/best-practices-for-listing.html)
- [Plugin configuration and change notes](https://plugins.jetbrains.com/docs/intellij/plugin-configuration-file.html)
- [macos-13 retirement](https://github.com/actions/runner-images/issues/13046)
- [macos-14 retirement](https://github.com/actions/runner-images/issues/13518)
- [Plugin Signing](https://plugins.jetbrains.com/docs/intellij/plugin-signing.html)

本报告位于 release-review/，不随 processResources 的 documentation/ 内容进入插件 ZIP。

## 协议与人工截图补充（2026-10-10）

已准备 docs/eula.md，沿用 MIT 并明确 JetBrains 非许可协议当事方；
隐私草案补充自愿支持材料的处理边界。公开名称 forest.li 已由发布者提供，
不据此推定个人/法人身份或 trader 状态。协议材料、截图已随包重建；
最终 EULA/隐私公开 URL、支持资料处理政策与原生第三方许可仍待确认。
提交步骤见 [marketplace-submission](marketplace-submission.md)。NO-GO 结论不变。

本次重建使用经官方 SHA-256 校验的临时 Temurin Java 21。check/buildPlugin 通过，
11 项测试无失败；从 ZIP 回读核对 MIT、EULA、隐私、notices、更新记录及五张人工截图。
因人工截图尺寸变化，文档测试由固定旧全屏尺寸改为检查可读尺寸；实际展示比例另行核对。
本机 IDE/Android Studio JBR 已变为 Java 25，旧构建环境记录不作为当前证据。
