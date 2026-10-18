#!/bin/bash
# Snowflake CLI 연결 설정(dbt_app)을 만든다. SVC_DBT의 비밀번호를 숨김 입력으로 받아 ~/.snowflake/connections.toml에 저장한다.
# 사용법: ./add-connection.sh
set -euo pipefail

FILE="$HOME/.snowflake/connections.toml"
NAME="dbt_app"

mkdir -p "$HOME/.snowflake"

if [[ -f "$FILE" ]] && grep -q "^\[$NAME\]" "$FILE"; then
  echo "연결 $NAME 이(가) 이미 있다. $FILE 에서 지운 뒤 다시 실행한다." >&2
  exit 1
fi

read -r -s -p "SVC_DBT 비밀번호: " PW
echo

# TOML 문자열 안의 \ 와 " 를 이스케이프해서 추가한다
ESCAPED=$(printf '%s' "$PW" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
unset PW

{
  [[ -s "$FILE" ]] && echo
  echo "[$NAME]"
  echo 'account = "<org>-<account>"'
  echo 'user = "SVC_DBT"'
  echo "password = \"$ESCAPED\""
  echo 'role = "DBT_APP"'
  echo 'warehouse = "DBT_WH"'
  echo 'database = "DBT_DEV"'
  echo 'schema = "NATIVE"'
} >> "$FILE"

# 비밀번호가 들어 있으니 본인만 읽도록 제한한다
chmod 600 "$FILE"
echo "연결 $NAME 을(를) 만들었다: $FILE"
