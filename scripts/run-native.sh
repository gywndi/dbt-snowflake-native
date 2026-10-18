#!/bin/bash
# Snowflake CLI로 dbt 프로젝트를 Snowflake 안에 배포하고 실행한다.
# 사용법: scripts/run-native.sh            (배포 + build)
#         scripts/run-native.sh deploy     (배포만)
#         scripts/run-native.sh execute    (build만)
set -euo pipefail

# 저장소 루트로 이동한다
cd "$(dirname "$0")/.."

# 계정 식별자와 유저는 환경변수에서 읽고, 없으면 물어본다. CLI가 같은 환경변수를 읽는다
if [[ -z "${SNOWFLAKE_ACCOUNT:-}" ]]; then
  read -r -p "계정 식별자(<org>-<account>): " SNOWFLAKE_ACCOUNT
fi
if [[ -z "${SNOWFLAKE_USER:-}" ]]; then
  read -r -p "유저: " SNOWFLAKE_USER
fi
export SNOWFLAKE_ACCOUNT SNOWFLAKE_USER

CONN=(--temporary-connection --role DBT_APP --warehouse DBT_WH --database DBT_DEV --schema NATIVE)

# Snowflake CLI가 없으면 가상환경에 설치한다
if ! command -v snow >/dev/null 2>&1; then
  [[ -d .venv ]] || python3 -m venv .venv
  source .venv/bin/activate
  command -v snow >/dev/null 2>&1 || pip install --quiet snowflake-cli
fi

# 비밀번호는 항상 화면에 보이지 않게 입력받는다 (터미널에 남은 옛 환경변수 값을 쓰지 않기 위해서다)
read -r -s -p "비밀번호: " SNOWFLAKE_PASSWORD
echo
export SNOWFLAKE_PASSWORD

STEP="${1:-all}"

if [[ "$STEP" == "all" || "$STEP" == "deploy" ]]; then
  echo "== 배포 =="
  snow dbt deploy snowflake_dbt_native --source dbt --profiles-dir dbt --default-target dev "${CONN[@]}"
fi

if [[ "$STEP" == "all" || "$STEP" == "execute" ]]; then
  echo "== 실행(build) =="
  # dbt 명령(build) 뒤의 인자는 전부 dbt로 넘어가므로 연결 옵션은 반드시 앞에 둔다
  snow dbt execute "${CONN[@]}" snowflake_dbt_native build
fi
