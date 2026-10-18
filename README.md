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

## 시험 결과

2026-10-18, 로컬에서 `run-native.sh`로 확인했다.

| 항목 | 결과 |
|---|---|
| 기능 활성 | 이 계정에서 `snow dbt deploy`로 프로젝트 객체가 만들어졌다 |
| 필요한 권한 | `DBT_APP`에 `DBT_DEV.NATIVE`의 `USAGE`와 `CREATE DBT PROJECT`만 주었고 배포가 통과했다 |
| 실행 | `snow dbt execute ... build`가 Snowflake 안에서 성공했다. 모델 5개와 테스트 10개, 합계 15개가 모두 통과했다(dbt 실행 6.69초) |
| dbt 버전 | 기본값 `1.9.4`(어댑터 `1.9.2`)로 실행됐다 |
| 다이내믹 테이블, 증분 모델 | 생성됐다. 다이내믹 테이블의 갱신 모드는 `FULL`이다. 원천이 공유 DB라서 변경 추적을 켤 수 없어 증분 갱신이 안 된다 |
| 임시 연결의 비밀번호 | `SNOWFLAKE_PASSWORD` 환경변수를 읽었다 |

`snow dbt execute`는 dbt 명령(`build`) 뒤의 인자를 전부 dbt로 넘긴다. 연결 옵션은 반드시 `build`보다 앞에 둔다. 뒤에 두면 `Connection default is not configured` 오류가 난다.

## 확인하지 않은 것

- 지원하는 dbt 버전 목록과 제한 사항, `--dbt-version`으로 올렸을 때의 동작.
- TASK 스케줄, 환경 분리(`env.yml`), Slim CI, 모니터링 설정.
- CI(GitLab)에서의 실행과 인증 방식(PAT, OIDC).
- 증분 모델의 두 번째 실행 결과.

## 시험 순서

CI 파일(`.gitlab-ci.yml`)은 아직 없다. 이 프로젝트에는 `SNOWFLAKE_PASSWORD` CI 변수가 없어서, 지금 추가하면 첫 파이프라인이 실패한다. 로컬 CLI로 먼저 동작을 확인한 뒤에 CI를 추가한다.

### 1. Snowflake 준비

Snowsight에서 `ACCOUNTADMIN`으로 실행한다. `setup/01-native-setup.sql`과 같은 내용이다.

```sql
USE ROLE ACCOUNTADMIN;

CREATE SCHEMA IF NOT EXISTS DBT_DEV.NATIVE;

GRANT USAGE ON SCHEMA DBT_DEV.NATIVE TO ROLE DBT_APP;
GRANT CREATE DBT PROJECT ON SCHEMA DBT_DEV.NATIVE TO ROLE DBT_APP;

SHOW GRANTS TO ROLE DBT_APP;
```

`CREATE DBT PROJECT` 권한이 인식되지 않아 오류가 나면, 이 계정에서 기능이 켜져 있지 않다는 첫 신호다.

### 2. 로컬에서 CLI 실행

위 "준비"와 "실행" 절의 명령을 순서대로 실행한다. 가상환경 생성과 CLI 설치, 비밀번호 입력, `snow dbt deploy`, `snow dbt execute ... build` 순서다.

### 3. 확인할 것

| 확인 항목 | 보는 곳 |
|---|---|
| 기능이 계정에서 켜져 있는지 | 1단계 `GRANT`, `snow dbt deploy` 오류 |
| 임시 연결에서 `SNOWFLAKE_PASSWORD`를 읽는지 | 인증 오류 여부. 오류가 나면 연결 설정 파일(`config.toml`)을 만드는 방식으로 바꾼다 |
| 모델 5개와 테스트 10개가 모두 통과하는지 | `snow dbt execute ... build` 출력 |
| 다이내믹 테이블, 증분 모델이 동작하는지 | `demo_dynamic`, `demo_incremental` 결과 |
| 지원하는 dbt 버전 | `--dbt-version` 옵션과 Snowflake 문서의 지원 버전 목록 |

### 4. 이후

로컬에서 성공하면 `when: manual` 작업 하나를 `.gitlab-ci.yml`에 추가한다. `pip install snowflake-cli`로 CLI를 설치하고 같은 두 명령을 실행한다. 그 전에 프로젝트 CI 변수에 `SNOWFLAKE_PASSWORD`(Masked)를 등록한다. 실행 시간은 `snowflake-dbt`의 CI 파드 실행(파이프라인 전체 약 68초)과 비교한다.
