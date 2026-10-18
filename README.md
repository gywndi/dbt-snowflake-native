# snowflake-dbt-native

dbt를 Snowflake 안에서 실행하는 방식(dbt Projects on Snowflake)을 Snowflake CLI로 시험하는 프로젝트다.
소스는 이 GitLab 저장소가 유일한 원천이고, `snow dbt deploy`가 체크아웃된 파일을 Snowflake로 올린다.
CI 파드에서 dbt를 직접 실행하는 `snowflake-dbt` 프로젝트와 같은 모델로 비교한다.

## 구성

| 항목 | 값 |
|---|---|
| dbt 프로젝트 객체 | `DBT_DEV.NATIVE.SNOWFLAKE_DBT_NATIVE` |
| 모델 결과 위치 | `DBT_DEV.NATIVE_TEST` |
| 실행 롤 | `DBT_APP` (`dbt_projects_profiles.yml`의 `role`) |
| 접속 계정 | `SVC_DBT` |
| 웨어하우스 | `DBT_WH` |

`dbt_projects_profiles.yml`은 `profiles.yml`보다 우선한다. Snowflake 안에서 실행되므로 계정 정보와 비밀번호가 없다.

## 준비

1. Snowsight에서 `ACCOUNTADMIN`으로 `setup/01-native-setup.sql`을 실행한다.
2. Snowflake CLI를 설치한다.

```bash
# 가상환경 생성 및 활성화
python3 -m venv .venv && source .venv/bin/activate

# Snowflake CLI 설치
pip install snowflake-cli

# 설치 확인
snow --version
```

## 실행

```bash
# 비밀번호는 화면에 안 보이게 입력
read -s "SNOWFLAKE_PASSWORD?비밀번호: " && export SNOWFLAKE_PASSWORD

# dbt 프로젝트 객체를 배포한다 (현재 디렉토리의 파일이 업로드됨)
snow dbt deploy snowflake_dbt_native --source . --profiles-dir . --default-target dev --temporary-connection --account <org>-<account> --user SVC_DBT --role DBT_APP --warehouse DBT_WH --database DBT_DEV --schema NATIVE

# Snowflake 안에서 dbt build를 실행한다
snow dbt execute snowflake_dbt_native build --temporary-connection --account <org>-<account> --user SVC_DBT --role DBT_APP --warehouse DBT_WH --database DBT_DEV --schema NATIVE
```

## 확인하지 않은 것

- 이 계정에서 해당 기능이 켜져 있는지, 지원하는 dbt 버전과 제한 사항.
- 다이내믹 테이블·증분 모델이 Snowflake 안에서 동작하는지.
- 임시 연결(`--temporary-connection`)에서 `SNOWFLAKE_PASSWORD` 환경변수가 읽히는지.
