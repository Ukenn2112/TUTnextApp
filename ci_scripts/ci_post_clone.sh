#!/bin/sh
# Xcode Cloud がリポジトリを clone した直後に実行するスクリプト。
#
# `tama/Resources/Config.xcconfig` は Google OAuth の ID を持つため git には入れていない（.gitignore）。
# しかし `tama` ターゲットの base configuration として参照しているので、無いと xcodebuild が
# プロジェクトを開いた時点で失敗する。ワークフローの Environment に secret として登録した
# `CLIENT_ID` / `REVERSED_CLIENT_ID` から、ここで同じ内容のファイルを生成する
set -eu

: "${CLIENT_ID:?Xcode Cloud のワークフローに環境変数 CLIENT_ID（secret）を設定してください}"
: "${REVERSED_CLIENT_ID:?Xcode Cloud のワークフローに環境変数 REVERSED_CLIENT_ID（secret）を設定してください}"

CONFIG_PATH="${CI_PRIMARY_REPOSITORY_PATH:?}/tama/Resources/Config.xcconfig"

cat > "$CONFIG_PATH" <<XCCONFIG
// Google OAuth Configuration（Xcode Cloud の ci_post_clone.sh が生成）
CLIENT_ID = ${CLIENT_ID}
REVERSED_CLIENT_ID = ${REVERSED_CLIENT_ID}
XCCONFIG

echo "Config.xcconfig を生成しました: $CONFIG_PATH"
