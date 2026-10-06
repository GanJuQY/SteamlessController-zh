#!/usr/bin/env bash
#
# 在 Linux 上交叉编译出「中文版 SteamlessController.exe」（MinGW-w64）
#
# 做四件事：
#   1. 拉上游 main 源码，打上中文补丁（SteamlessController-zh-CN.patch）
#   2. 打上编码修复补丁（utf8-widen-fix.patch）—— 缺了这步，界面里的中文会是
#      «è‡ªå®šä¹‰æŽ§å¶» 这种乱码：上游把这段 HTML 假定成纯 ASCII，
#      转宽字符串时「一个字节塞一个 wchar_t」，ASCII 看不出问题，中文就散了。
#   3. 打上 MinGW 移植补丁（mingw-port.patch，3 个文件，见《安装说明》）
#   4. 用 mingw-w64 交叉编译，产出 out/SteamlessController.exe
#
# 依赖（Ubuntu/Debian）：
#   sudo apt update && sudo apt install -y cmake ninja-build g++-mingw-w64-x86-64 mingw-w64-tools curl unzip
#
# 用法：
#   bash scripts/mingw-build.sh      # 工作目录默认 /tmp/ssc-crossbuild
#   WORK=/path/to/work bash mingw-build.sh
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${WORK:-/tmp/ssc-crossbuild}"
UPSTREAM_TARBALL="https://codeload.github.com/ddeverill/SteamlessController/tar.gz/refs/heads/main"
WV2_VER="1.0.2849.39"
JOBS="$(nproc)"

PATCH_DIR="$HERE/../patches"
ZH_PATCH="$PATCH_DIR/SteamlessController-zh-CN.patch"
UTF8_PATCH="$PATCH_DIR/utf8-widen-fix.patch"
PORT_PATCH="$PATCH_DIR/mingw-port.patch"
[ -f "$ZH_PATCH" ]   || { echo "缺少 $ZH_PATCH" >&2; exit 1; }
[ -f "$UTF8_PATCH" ] || { echo "缺少 $UTF8_PATCH" >&2; exit 1; }
[ -f "$PORT_PATCH" ] || { echo "缺少 $PORT_PATCH" >&2; exit 1; }

# ---- 工具链检查 --------------------------------------------------------------
for t in cmake ninja x86_64-w64-mingw32-g++ x86_64-w64-mingw32-windres curl unzip; do
    command -v "$t" >/dev/null || { echo "缺少 $t，请先装依赖（见脚本头部）" >&2; exit 1; }
done

MINGW_INC=""
for cand in /usr/x86_64-w64-mingw32/include /usr/share/mingw-w64/include /usr/local/x86_64-w64-mingw32/include; do
    [ -e "$cand/windows.h" ] && MINGW_INC="$cand" && break
done
[ -n "$MINGW_INC" ] || { echo "找不到 mingw-w64 头文件目录" >&2; exit 1; }

mkdir -p "$WORK"
cd "$WORK"

# ---- 1) 上游源码 -------------------------------------------------------------
if [ ! -f src/CMakeLists.txt ]; then
    echo "== 下载上游 main 源码 =="
    curl -sL "$UPSTREAM_TARBALL" -o upstream.tgz
    rm -rf src && mkdir src
    tar xzf upstream.tgz -C src --strip-components=1
fi

cd src
[ -d .git ] || git init -q .

apply_patch() {
    local f="$1"
    if git apply -p1 --check "$f" 2>/dev/null; then
        git apply -p1 "$f"; echo "== 已应用 $(basename "$f")"
    elif git apply -p1 --reverse --check "$f" 2>/dev/null; then
        echo "== 已应用过，跳过 $(basename "$f")"
    else
        echo "补丁打不上：$f（源码版本可能变了）" >&2; exit 1
    fi
}
apply_patch "$ZH_PATCH"
apply_patch "$UTF8_PATCH"
apply_patch "$PORT_PATCH"

# ---- 2) WebView2 SDK（NuGet 包就是个 zip） ------------------------------------
if [ ! -f "$WORK/wv2/build/native/include/WebView2.h" ]; then
    echo "== 下载并解包 WebView2 SDK =="
    mkdir -p "$WORK/wv2"
    curl -sL "https://www.nuget.org/api/v2/package/Microsoft.Web.WebView2/$WV2_VER" -o "$WORK/wv2.nupkg"
    (cd "$WORK/wv2" && unzip -q -o "$WORK/wv2.nupkg")
fi

# ---- 3) 大小写垫片 -----------------------------------------------------------
# 源码写的是 <Windows.h> 这种 MSVC 风格头名，Windows 上不分大小写，Linux 上分。
# 造一批符号链接把首字母大写的写法指到 mingw 的小写真头上去。
SHIM="$WORK/winshim"
mkdir -p "$SHIM"
for h in Windows.h SetupAPI.h ShlObj.h TlHelp32.h EventToken.h; do
    low="$(echo "$h" | tr 'A-Z' 'a-z')"
    [ -e "$SHIM/$h" ] && continue
    if   [ -e "$MINGW_INC/$low" ]; then ln -sf "$MINGW_INC/$low" "$SHIM/$h"
    elif [ -e "$MINGW_INC/$h"   ]; then ln -sf "$MINGW_INC/$h"   "$SHIM/$h"
    fi
done

# ---- 4) 交叉编译 -------------------------------------------------------------
cat > "$WORK/mingw-toolchain.cmake" <<'EOF'
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)
# CMake 探测编译器时会试链一个带 main() 的小程序，而本工程链接时要 -municode
# （入口变成 wWinMain），两者冲突会让探测失败 —— 交叉编译时改成只编译不链接。
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
set(CMAKE_C_COMPILER   x86_64-w64-mingw32-gcc)
set(CMAKE_CXX_COMPILER x86_64-w64-mingw32-g++)
set(CMAKE_RC_COMPILER  x86_64-w64-mingw32-windres)
set(CMAKE_FIND_ROOT_PATH /usr/x86_64-w64-mingw32)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
EOF

echo "== configure =="
# --no-insert-timestamp：PE 头里不写链接时刻，同样的源码 + 同样的补丁能编出
# 字节完全一样的 exe（sha256 可复算），否则每次链接都会因为时间戳而变。
cmake -S "$WORK/src" -B "$WORK/build" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$WORK/mingw-toolchain.cmake" \
    -DFETCHCONTENT_SOURCE_DIR_WEBVIEW2="$WORK/wv2" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_FLAGS="-I$SHIM" \
    -DCMAKE_EXE_LINKER_FLAGS="-municode -static -static-libgcc -static-libstdc++ -Wl,--no-insert-timestamp" >/dev/null

echo "== build SteamlessController =="
cmake --build "$WORK/build" --target SteamlessController -j"$JOBS"

# ---- 5) 收尾 ----------------------------------------------------------------
OUT="$WORK/out"
mkdir -p "$OUT"
cp -f "$WORK/build/SteamlessController.exe" "$OUT/"
# 本构建动态链接 WebView2Loader.dll（官方 MSVC 构建是静态链接，所以官方安装目录里没有这个 DLL）
cp -f "$WORK/wv2/build/native/x64/WebView2Loader.dll" "$OUT/"

echo
echo "完成："
ls -l "$OUT"
(cd "$OUT" && sha256sum SteamlessController.exe WebView2Loader.dll)
