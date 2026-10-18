#!/bin/bash
# Snowflake CLI로 dbt 프로젝트를 Snowflake 안에 배포하고 실행한다.
# 사용법: ./run-native.sh            (배포 + build)
#         ./run-native.sh deploy     (배포만)
#         ./run-native.sh execute    (build만)
set -euo pipefail

cd "$(dirname "$0")"

ACCOUNT="<org>-<account>"
CONN=(--temporary-connection --account "$ACCOUNT" --user SVC_DBT --role DBT_APP --warehouse DBT_WH --database DBT_DEV --schema NATIVE)

# Snowflake CLI가 없으면 가상환경에 설치한다
if ! command -v snow >/dev/null 2>&1; then
  [[ -d .venv ]] || python3 -m venv .venv
  source .venv/bin/activate
  command -v snow >/dev/null 2>&1 || pip install --quiet snowflake-cli
fi

# 비밀번호는 항상 화면에 보이지 않게 입력받는다 (터미널에 남은 옛 환경변수 값을 쓰지 않기 위해서다)
read -r -s -p "SVC_DBT 비밀번호: " SNOWFLAKE_PASSWORD
echo
export SNOWFLAKE_PASSWORD

STEP="${1:-all}"

if [[ "$STEP" == "all" || "$STEP" == "deploy" ]]; then
  echo "== 배포 =="
  snow dbt deploy snowflake_dbt_native --source . --profiles-dir . --default-target dev "${CONN[@]}"
fi

if [[ "$STEP" == "all" || "$STEP" == "execute" ]]; then
  echo "== 실행(build) =="
  # dbt 명령(build) 뒤의 인자는 전부 dbt로 넘어가므로 연결 옵션은 반드시 앞에 둔다
  snow dbt execute "${CONN[@]}" snowflake_dbt_native build
fi
