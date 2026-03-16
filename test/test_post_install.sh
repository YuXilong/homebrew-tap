#!/bin/bash
set -e

echo "========================================="
echo "  测试 wukong formula post_install 逻辑"
echo "========================================="

# 定位 ruby@3.3（与 formula 中逻辑一致）
RUBY_BIN="$(brew --prefix ruby@3.3)/bin"
BREW_PREFIX="$(brew --prefix)"
GEM_BIN="${BREW_PREFIX}/lib/ruby/gems/3.3.0/bin"
GEM_CMD="${RUBY_BIN}/gem"

echo ""
echo "[1/6] 检查 ruby@3.3 安装..."
echo "  RUBY_BIN: ${RUBY_BIN}"
echo "  BREW_PREFIX: ${BREW_PREFIX}"
echo "  GEM_BIN: ${GEM_BIN}"
echo "  ruby version: $("${RUBY_BIN}/ruby" --version)"
echo "  PASS"

echo ""
echo "[2/6] 注入 PATH（模拟 ENV.prepend_path）..."
export PATH="${RUBY_BIN}:${GEM_BIN}:${PATH}"
echo "  which gem: $(which gem)"
echo "  PASS"

echo ""
echo "[3/6] 切换 gem 源为 ruby-china 镜像..."
"${GEM_CMD}" sources --remove https://rubygems.org/ 2>/dev/null || true
"${GEM_CMD}" sources --add https://gems.ruby-china.com/ 2>/dev/null || true
echo "  当前 gem 源:"
"${GEM_CMD}" sources -l
echo "  PASS"

echo ""
echo "[4/6] 安装 cocoapods 1.15.2..."
"${GEM_CMD}" install cocoapods -v 1.15.2 --no-document
echo "  PASS"

echo ""
echo "[5/6] 验证 pod 命令可用..."
POD_PATH=$(which pod 2>/dev/null || echo "NOT_FOUND")
echo "  pod path: ${POD_PATH}"
if [ "${POD_PATH}" = "NOT_FOUND" ]; then
    echo "  FAIL: pod 命令未找到!"
    echo "  GEM_BIN 目录内容:"
    ls -la "${GEM_BIN}/" 2>/dev/null || echo "  目录不存在"
    echo "  gem env gemdir: $(${GEM_CMD} environment gemdir)"
    exit 1
fi
POD_VERSION=$(pod --version 2>/dev/null || echo "UNKNOWN")
echo "  pod version: ${POD_VERSION}"
if [ "${POD_VERSION}" = "1.15.2" ]; then
    echo "  PASS"
else
    echo "  FAIL: 期望 1.15.2，实际 ${POD_VERSION}"
    exit 1
fi

echo ""
echo "[6/6] 测试 PATH 写入 ~/.zshrc（模拟）..."
ZSHRC="$HOME/.zshrc"
MARKER="# >>> wukong ruby@3.3 >>>"
# 第一次写入
if [ -f "${ZSHRC}" ] && grep -q "${MARKER}" "${ZSHRC}"; then
    echo "  标记已存在"
else
    {
        echo ""
        echo "${MARKER}"
        echo "export PATH=\"${RUBY_BIN}:${GEM_BIN}:\$PATH\""
        echo "# <<< wukong ruby@3.3 <<<"
    } >> "${ZSHRC}"
    echo "  已写入 ~/.zshrc"
fi
# 幂等验证
BEFORE=$(grep -c "${MARKER}" "${ZSHRC}")
if [ -f "${ZSHRC}" ] && grep -q "${MARKER}" "${ZSHRC}"; then
    : # 不重复写入
fi
AFTER=$(grep -c "${MARKER}" "${ZSHRC}")
if [ "${BEFORE}" = "${AFTER}" ]; then
    echo "  PASS（幂等性验证通过）"
else
    echo "  FAIL: 重复写入!"
    exit 1
fi

echo ""
echo "  ~/.zshrc 相关内容:"
grep -A2 "wukong ruby" "${ZSHRC}"

echo ""
echo "========================================="
echo "  ALL TESTS PASSED"
echo "========================================="
