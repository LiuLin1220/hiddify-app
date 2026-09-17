# macOS 应用图标缺失：打包验证与台前调度排障

适用于本 fork 的 macOS 个人构建。本文记录 2026-09-17 的一次实际故障，供后续发布和排障复用；不是针对所有 macOS 设备的通用修复脚本。

关联：[故障记录 #1](https://github.com/LiuLin1220/hiddify-app/issues/1) · [代码集成 PR #2](https://github.com/LiuLin1220/hiddify-app/pull/2)。Issue 的解决状态与 PR 的合并状态分别维护。

## 结论与证据边界

这次存在两个独立问题：

1. **安装包缺少可用的应用图标，已确认并修复。** 工程只引用 Icon Composer 的 `AppIcon.icon`，没有传统 `AppIcon.appiconset`。本次 Xcode 16.4 构建把图标源文件作为资源放入应用，却没有生成有效的图标声明和 `AppIcon.icns`。Dock 因此显示占位图标。
2. **安装包修复后，台前调度仍显示占位图标，已恢复，但内部根因未完全确定。** Dock、Finder 图标查询和应用切换图标已经正常；相同程序和图标换用临时应用标识后，台前调度也正常。最终，在确认系统及当前用户图标服务真正重新启动后，再刷新 Dock 和 WindowManager，原标识下的图标恢复正常，并由用户确认。

第二项证据支持“原应用标识对应的系统图标状态异常”，但没有证明具体哪个缓存文件、单个服务或单条命令负责，也不能据此认定为 macOS 26 的普遍缺陷。首次发现的旧 Launch Services 记录是线索，不是已证实的唯一根因。

## 环境和可追溯结果

| 项目 | 本次验证值 |
| --- | --- |
| 应用 | Hiddify 4.1.2 dev，构建号 40102 |
| Flutter / 构建工具 | Flutter 3.38.5；Xcode 16.4；macOS 15 Apple 芯片 CI |
| 使用设备系统 | macOS 26.5.2，Apple 芯片 |
| 产物 | Universal DMG / PKG，arm64 与 x86_64，最低 macOS 12 |
| 签名 | ad-hoc，未做 Apple 公证 |
| Core | `9a25b85ed97f0416ec38e0e9823a23ecb61f35b1` |
| sing-box | `170d8315cab7a8695fd80469073ed2f1d07d63af` |
| 已验证的代码提交 | `3534e2cbf92030ba4e60b48319dc6af71b57a79c` |

- [首次可交付构建](https://github.com/LiuLin1220/hiddify-app/actions/runs/35182125379)：构建、签名及包完整性检查成功，但当时没有图标检查，因此未能发现缺图标。
- [补齐图标后的成功构建](https://github.com/LiuLin1220/hiddify-app/actions/runs/35184886432)：包含应用及挂载后 DMG 的图标检查、解码预览、签名检查和 Core 加载验证。
- 修复提交：`36eef431` 恢复标准图标并加入检查；`3534e2cb` 按实际解码结果选择预览图。

Actions 产物有保留期限。长期证据应保留提交、工作流、校验记录和脱敏结论，不依赖下载链接永久有效。

## 第一层：检查实际安装包

不要只检查源码图片是否存在，也不要把 CI 成功等同于图标显示正常。先确认运行路径和安装位置；仅有 Spotlight 的一条结果，不代表 Launch Services 没有遗留注册记录。

以下只读命令在 **Mac 的 Terminal（zsh / bash）** 中执行：

```sh
ps -axo command= | grep '[H]iddify.app/Contents/MacOS/Hiddify'
mdfind 'kMDItemCFBundleIdentifier == "app.hiddify.com"'

app="/Applications/Hiddify.app"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "$app/Contents/Info.plist"
ls -l "$app/Contents/Resources/AppIcon.icns" "$app/Contents/Resources/Assets.car"
codesign --verify --deep --strict "$app"
```

路径和图标文件名应以实际安装及 plist 为准。传统独立 ICNS 方案可以没有 `CFBundleIconName`；缺少这个键本身不能判定失败。

本 fork 的固定构建路径采用传统 `AppIcon.appiconset`，由 Xcode 生成图标声明及资源。新旧图标格式的选择必须与构建工具匹配。

### CI 必须检查什么

- [工作流](../../.github/workflows/build-macos-personal.yml) 使用固定 App / Core 来源，并校验架构、签名、Core 加载及 DMG / PKG。
- [图标检查脚本](../../.github/scripts/verify-macos-icon.py) 要求 `CFBundleIconFile` 指向真实存在、头部与长度有效的 ICNS。
- 使用 `iconutil` 实际解码，并从输出 PNG 中选择最大尺寸的图像作为 `AppIcon-preview.png`。不能假定一定生成 `icon_512x512@2x.png`。
- 挂载最终 DMG 后，再检查一次包内应用的图标声明、文件和签名。
- 下载产物后核对 `SHA256SUMS.txt`，人工查看从编译产物导出的预览。

本次新增检查已用旧版 DMG 的真实 plist 做过回归验证：旧包因缺少图标声明被拒绝。ICNS 检查和预览仍然不能覆盖真机所有系统界面。

## 第二层：区分不同界面的症状

至少分别记录 Finder、Dock、⌘Tab、台前调度的结果。本次用户确认 Dock 和 ⌘Tab 正常，只有台前调度异常；通过 `NSWorkspace` / `NSRunningApplication` 查询并导出的图标也正常。

| 本次操作或观察 | 结果与能支持的判断 |
| --- | --- |
| 正常退出并重新打开应用；关闭再开启台前调度 | 用户反馈无效；不要反复要求相同操作 |
| 核对运行路径、图标文件与资源目录 | 确认正在使用修复版，图标资源完整 |
| 定向注销两条 DMG 遗留记录，重新注册正式应用 | 最终仅剩正式安装路径，但显示问题未恢复 |
| 重启 Dock、WindowManager，再重开应用 | 无效；不能据此声称系统图标服务已刷新 |
| 独立完整 ICNS 替代资源目录引用，并重新签名 | 无效，已回滚；没有证据要求更换正式图标方案 |
| 相同程序、相同图标，仅测试副本使用新应用标识 | 用户确认正常，提示异常与原标识对应的系统状态有关 |
| 原标识下仅提高构建号 | 无效，已恢复 40102；不能把重复构建号写成已确认根因 |
| 确认系统图标服务及用户图标代理换成新进程，再刷新 Dock / WindowManager | 原标识下恢复正常，用户确认；这是验证成功的操作组合 |

早期向用户图标代理发送普通终止信号后，其 PID 没有变化，因此那次不能记作“成功重启”。后续确认原进程退出、服务自动拉起了新进程，才具备刷新服务的证据。不要仅根据命令退出码报告重启成功。

## 最小修复、授权与回滚

1. 先记录症状和实际包信息；安装包缺图标时，修复构建并验证产物。
2. 包正确而单个界面异常时，检查应用注册和运行中图标，再形成可证伪假设。
3. 定向修改注册、重启系统界面或服务前，说明影响并取得对应授权。不要默认删除所有图标缓存或重建全系统应用数据库。
4. 如需重新启动服务，先核对可执行路径、所属用户及 PID；区分系统服务与当前用户代理。只有确认普通终止无效后，才考虑更强的终止方式，并核验自动恢复。本文不提供未经核对即可执行的批量强杀命令。
5. 修改安装包前完整备份。图标或 plist 变化会影响签名，需要重新签名并验证；试验无效时恢复正式包。不要只修了资源而留下失效签名。
6. 应用标识对照只用于诊断。先保护配置和数据库，避免并发运行；不能把新标识随意留作正式修复，否则可能影响偏好、权限和登录启动。
7. 以用户设备上的实际显示结果验收，随后核对正式标识、版本、签名、运行状态及数据完整性。

特别注意：本次代码的 macOS 数据库路径使用 `getLibraryDirectory()`，不是按 bundle ID 隔离的应用支持目录。**更换 bundle ID 不等于隔离数据库。** 本次在原应用退出后备份数据库，结束后校验一致；测试副本已退出并注销。备份留在本机用于回滚，不提交仓库。

## 发布验收与记录规范

- 同时记录“包内检查通过”和“真机各界面结果”，避免把前者扩大为全部修复完成。
- 每次交付记录完整提交、Core 版本、构建运行、工具链、签名方式及包哈希。
- 新构建应保持可区分的版本和产物记录，便于排查；这是一项可追溯性建议，不是本次系统状态异常的已证实修复。
- 公开记录只保留必要的脱敏证据。不要上传原始 `lsappinfo -all`、完整注册数据库、用户路径、设备名、订阅配置、密码或沙箱令牌。
- Issue 记录问题与处理进展，PR 说明可审查的代码变化，本文保存可复用流程。系统侧恢复结果与代码修复分别标明，不把本机现象包装成未经复现的上游缺陷。

## 参考

- [Apple：配置资源目录中的应用图标](https://developer.apple.com/documentation/xcode/configuring-your-app-icon)
- [Apple：CFBundleIconFile](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleiconfile)
- [Apple：CFBundleIconName](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleiconname)
