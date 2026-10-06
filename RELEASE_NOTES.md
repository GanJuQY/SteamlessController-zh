# SteamlessController 简体中文版 — zh-v2

第一个中文能正常显示的版本。**zh-v1 不要用**：它的「自定义控制」窗口全是
`è‡ªå®šä¹‰æŽ§å¶` 这种乱码（上游 `GetHtml()` 把 UTF-8 一个字节当一个 `wchar_t` 的 bug，
英文界面全 ASCII 所以从没暴露）。

## 下载哪个

- `SteamlessController.exe` —— 汉化主程序，覆盖进安装目录
- `WebView2Loader.dll` —— **必须一起放**，本构建动态链接它（官方 MSVC 版是静态链接，所以官方目录里没有）
- `SteamlessController-zh-v2.zip` —— 上面两个 + `安装说明.md` + 三个源码补丁

## 安装

1. 先装官方 v1.24 安装包（内含 ViGEmBus 1.22.0 前置驱动）
2. 右下角托盘图标 → 右键 → 退出
3. 覆盖 `C:\Program Files\SteamlessController\SteamlessController.exe`，并新增 `WebView2Loader.dll`
4. `SteamlessDeviceCycle.exe`、`ViGEmBusProbe.exe` 保持官方的别动

## 校验（SHA-256）

```
97393045bd3224d25315dff1cc62c827d34c0e0c996b53f3c92b9dc92c60c992  SteamlessController.exe
1d963a02d8a7fa3e7eac2e936dad5559c4d63327f35b0a09787ffc1d58f9c18d  WebView2Loader.dll
```

可复算：`scripts/mingw-build.sh` 链接时带 `-Wl,--no-insert-timestamp`，所以在两个互不相干的目录里
各跑一次，编出来的 exe 字节完全一致（上面这个 sha256 就是这么来的）。CI 编出来的和 Release 里的
成品是同一个文件。

## 这一版改了什么

- 修内嵌 HTML 的 UTF-8 解码（`patches/utf8-widen-fix.patch`，1 个文件 2 处）：
  `MultiByteToWideChar(CP_UTF8, ...)` 替换掉「每字节一个 wchar_t」的写法。
  验证方式：把真实的 79629 字节 HTML 载荷分别用新旧两种转法跑一遍，旧写法查不到任何中文，
  新写法 `自定义控制` / `重新绑定` / `搜索游戏或程序` 全部命中。

## 基于

上游 `main` 分支（界面显示版本号 1.25，比已发布的 v1.24 多了扳机设置那块），
2026-10-05 用 MinGW-w64 在 Linux 上交叉编译。

## 已知差异与限制

- 商店 / MSIX 游戏（Xbox Game Pass 那类）不会出现在游戏选择器里 —— MinGW 没有 C++/WinRT，
  上游用它枚举打包游戏；普通 exe / Steam / 启动器游戏（Epic、Ubisoft、Battle.net、GOG）不受影响。
- exe 未签名，SmartScreen 可能提示。
- 版本号显示 1.25，但官方安装包写进「应用和功能」的卸载条目仍是 1.24。
