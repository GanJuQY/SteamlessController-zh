# SteamlessController 简体中文版（非官方）

[SteamlessController](https://github.com/ddeverill/SteamlessController) 的**非官方简体中文汉化**
（上游 MIT License，© 2026 Dylan Deverill）。

这个仓库放的是**汉化补丁 + 构建脚本**，不是上游源码的镜像；编译好的 exe 在 Releases 里。

| 想干的事 | 去哪 |
| --- | --- |
| 下载编好的中文版 | [Releases → zh-v2](https://github.com/GanJuQY/SteamlessController-zh/releases/tag/zh-v2) |
| 自己编一份 | `bash scripts/mingw-build.sh`（见 [`docs/安装说明.md`](docs/安装说明.md)） |
| 看补丁改了什么 | [`patches/`](patches) 三个补丁，一个汉化、一个 UTF-8 修复、一个 MinGW 移植 |
| 发布与维护流程 | [`docs/发布与维护.md`](docs/发布与维护.md) |

> Unofficial Simplified-Chinese localisation for SteamlessController.
> This repository carries patches and a build script — not a copy of upstream source.
> Prebuilt binaries are attached to Releases.

## 汉化了什么

- 托盘菜单、右键菜单、气泡提示、所有对话框；
- 「自定义控制」窗口里整页 HTML/CSS/JS 的全部可见文案（约 1300 个汉字）；
- 中文回退字体（`Microsoft YaHei UI` / `Noto Sans SC`），中文不会掉成方框。

**故意不翻**的：键盘/手柄按键名、Steam 的 `[PlayStation]` / `[Xbox]` 标记、程序名
`Steamless Controller`（这些是标识，翻了反而对不上）；日志、注册表值、JSON 协议串也不动。

## 装（3 步）

1. 先装官方 v1.24 安装包（内含 ViGEmBus 1.22.0 前置驱动）：
   <https://github.com/ddeverill/SteamlessController/releases/download/v1.24/SteamlessController-Setup.exe>
2. 右下角托盘图标 → 右键 → 退出（不退出 exe 被占用，覆盖不进去）。
3. 把本仓库 Release 里的两个文件放进 `C:\Program Files\SteamlessController\`：

   | 文件 | 动作 | 说明 |
   | --- | --- | --- |
   | `SteamlessController.exe` | 覆盖同名文件 | 汉化主程序 |
   | `WebView2Loader.dll` | **新增**，别删 | 本构建动态链接它；官方 MSVC 版是静态链接，所以官方目录里本来没有这个 DLL |

   `SteamlessDeviceCycle.exe`、`ViGEmBusProbe.exe` 保持官方的别动（没用中文需求，官方源里它们与 main 逐行一致，混用安全）。

## 为什么是「重新编译」而不是一个语言包

上游源码里没有任何本地化机制：`resources/app.rc` 连 `STRINGTABLE` 都没有，界面文字全部硬编码在
C++ 字面量（`src/app/TrayApp.cpp`、`src/app/RemapWindow.cpp`）和一段内嵌 HTML 里。
所以汉化只能是「改源码 + 重新编译」，不存在外挂式中文包 —— 这两个补丁就是那套改动。

## 从源码构建

### Windows / MSVC（官方推荐工具链）

需要 VS2022 + CMake 3.20+ + Windows SDK 10.0.22000+。

```powershell
git clone https://github.com/ddeverill/SteamlessController.git
cd SteamlessController
git apply ..\patches\SteamlessController-zh-CN.patch
git apply ..\patches\utf8-widen-fix.patch
cmake -B build/release -G "Visual Studio 17 2022"
cmake --build build/release --config Release --target SteamlessController
```

> `--config Release` **不能省**：VS 生成器是多配置的，漏了会静默编出 Debug 版（上游 README 也警告过这一点）。
> 产物在 `build\release\Release\SteamlessController.exe`。
> `mingw-port.patch` 是给 MinGW 用的，MSVC 不需要打。

### Linux 交叉编译（MinGW-w64）

```bash
sudo apt update && sudo apt install -y cmake ninja-build g++-mingw-w64-x86-64 mingw-w64-tools curl unzip
bash scripts/mingw-build.sh            # 工作目录默认 /tmp/ssc-crossbuild，可用 WORK= 覆盖
```

脚本会拉上游 main、按顺序打三个补丁、下载 WebView2 SDK（NuGet 包），产出
`out/SteamlessController.exe` + `out/WebView2Loader.dll`。CI 定义放在 `ci/build.yml`
（GitHub 的 `.github/workflows/` 目录要求推送用的 token 带 `workflow` 权限，所以这里存一份副本，
启用方法见 `PUBLISH.md`）。

链接时带了 `-Wl,--no-insert-timestamp`（PE 头里不写链接时刻），所以同样的源码 + 同样的补丁，
在任何目录、任何时候编出来的 exe **字节完全一致**，sha256 可以自己复算；CI 产物和 Release 里的
成品是同一个文件。

## 三个补丁分别是

| 补丁 | 作用 | 谁需要 |
| --- | --- | --- |
| `patches/SteamlessController-zh-CN.patch` | 汉化本身（对上游 main，198 条字符串替换全部命中） | 所有想用中文版的人 |
| `patches/utf8-widen-fix.patch` | 修内嵌 HTML 的 UTF-8 解码：`src/app/RemapWindow.cpp` 的 `GetHtml()` 原来是「一个字节塞一个 `wchar_t`」，英文界面全 ASCII 所以上游一直没暴露，换成中文就散成 `è‡ªå®šä¹‰` 这种乱码 | **必需**，MSVC 自编也得打 |
| `patches/mingw-port.patch` | MinGW 移植 3 处：`GameLibrary.cpp` 的 C++/WinRT 段条件编译、`CMakeLists.txt` 改用 `WebView2Loader.dll.lib` 并去掉 mingw 没有的 `windowsapp`、`RemapWindow.cpp` 补一个 `Microsoft::WRL::Callback` 等价实现（mingw 的 WRL 缺 `wrl/implements.h`） | 只有 MinGW 交叉编译需要 |

## 已知差异与限制

- **商店 / MSIX 游戏不在列表里**：上游用 C++/WinRT 的 `PackageManager` 枚举 Xbox Game Pass 那类打包游戏，
  MinGW 没有 C++/WinRT，这段被条件编译掉了。普通 exe 游戏、Steam 游戏、启动器游戏
  （Epic / Ubisoft / Battle.net / GOG 等）不受影响。MSVC 自编中文版没有这个差异。
- **exe 未签名**：自行编译，没有代码签名证书，SmartScreen 可能提示。需要官方版时重装官方安装包即可。
- **版本号显示 1.25**：汉化基于上游 `main`（比已发布的 v1.24 新一点，多了扳机设置那块）。
  官方安装包写进「应用和功能」的卸载条目仍是 1.24，不影响使用。
- **测试程度**：exe 在 Windows 上启动过、窗口能正常显示；MinGW 构建经过可复现性验证和字符串比对，
  但没有在真机手柄上跑完整链路（那部分与补丁无关，是上游逻辑）。

## 版本记录

| 版本 | 内容 |
| --- | --- |
| `zh-v2` | 修掉内嵌页面乱码（`utf8-widen-fix.patch`）；构建改为可复现（`-Wl,--no-insert-timestamp`） |
| `zh-v1` | 首次汉化（乱码未修，已废弃） |

## 许可与致谢

- 本仓库的改动（汉化、UTF-8 修复、MinGW 移植）按 **MIT** 发布，见 [LICENSE](LICENSE)；
  上游代码与二进制仍归 © 2026 Dylan Deverill（MIT）。
- `WebView2Loader.dll` 取自微软官方 NuGet 包 `Microsoft.Web.WebView2`（可再分发组件）。
- [ViGEmBus](https://github.com/nefarius/ViGEmBus) 是独立安装的第三方驱动，本仓库不含它。

## 免责

非官方汉化，与上游作者无关；按 MIT「AS IS」提供，不担保任何用途。
手柄 / 反作弊 / 账号风险请自行评估。

## 回滚

重装一遍官方安装包即回到官方版。
