#!/bin/bash
# ============================================================
# MovieTool - GitHub 一键推送脚本
# 使用方法: bash push_to_github.sh
# ============================================================

set -e

echo "=========================================="
echo "  MovieTool - GitHub 推送工具"
echo "=========================================="
echo ""

# 检查 git
if ! command -v git &> /dev/null; then
    echo "❌ 未安装 git，请先安装:"
    echo "   Ubuntu/Debian: sudo apt install git"
    echo "   MacOS: brew install git"
    echo "   Windows: https://git-scm.com/"
    exit 1
fi

echo "✅ Git 已安装: $(git --version)"

# 检查是否已有远程仓库
if git remote -v 2>/dev/null | grep -q origin; then
    echo "ℹ️  远程仓库已配置:"
    git remote -v
    echo ""
    read -p "是否推送到当前远程仓库? (y/n): " push_confirm
    if [ "$push_confirm" != "y" ]; then
        echo "请手动修改远程仓库地址: git remote set-url origin <新地址>"
        exit 0
    fi
else
    echo ""
    echo "请输入 GitHub 仓库信息:"
    read -p "GitHub 用户名: " github_user
    read -p "仓库名称 (默认: movie_tool): " repo_name
    repo_name=${repo_name:-movie_tool}
    
    echo ""
    echo "配置远程仓库: git@github.com:$github_user/$repo_name.git"
    git remote add origin "git@github.com:$github_user/$repo_name.git"
fi

echo ""
echo "📦 添加所有文件到 Git..."
git add -A

echo ""
echo "📝 创建提交..."
git commit -m "Initial commit: MovieTool 跨平台电影聚合播放器

- Flutter 跨平台电影聚合播放器
- XPath 网页解析引擎，无后端服务
- 支持 kazumi:// 和 JSON 规则导入
- 集成 video_player + WebView 双模式播放
- 支持倍速、全屏、防盗链 Header
- 内置6个电影源规则
- 配置 GitHub Actions 自动编译 APK/AAB"

echo ""
echo "🚀 推送到 GitHub..."
echo "   (如果 SSH 认证失败，请先配置 SSH Key)"
echo "   或使用: git push -u origin main --force"
echo ""

if git push -u origin main 2>/dev/null; then
    echo ""
    echo "=========================================="
    echo "  ✅ 推送成功！"
    echo "=========================================="
    echo ""
    echo "GitHub Actions 将自动编译 APK:"
    echo "  1. 打开 https://github.com/$github_user/$repo_name/actions"
    echo "  2. 等待 \"Build MovieTool APK\" 工作流完成"
    echo "  3. 点击最新运行记录"
    echo "  4. 在 \"Artifacts\" 区域下载:"
    echo "     - movie-tool-apk → APK 安装包"
    echo "     - movie-tool-aab → Google Play 发布包"
else
    echo ""
    echo "⚠️  推送失败，尝试备用方案..."
    echo "请手动执行:"
    echo "  git push -u origin main"
    echo ""
    echo "或使用 Token 认证:"
    echo "  git remote set-url origin https://<token>@github.com/$github_user/$repo_name.git"
    echo "  git push -u origin main"
fi