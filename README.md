# dbt-snowflake-native

dbt를 Snowflake 안에서 실행하는 방식(dbt Projects on Snowflake)을 Snowflake CLI로 시험한 프로젝트다.
소스의 유일한 원천은 이 GitLab 저장소이고, `snow dbt deploy`가 체크아웃된 파일을 Snowflake로 올린다.
CI 파드에서 dbt를 직접 실행하는 `dbt-snowflake-ci` 프로젝트와 같은 모델로 비교했다.

## 구성 한눈에

```
GitLab 저장소 ── snow dbt deploy ──▶ dbt 프로젝트 객체 (DBT_DEV.NATIVE.SNOWFLAKE_DBT_NATIVE)
                                          │  snow dbt execute / TASK
                                          ▼
                              Snowflake 안에서 dbt 실행 (프로필의 role 권한)
                                          ▼
                              모델 결과 (DBT_DEV.NATIVE_TEST)
```

| 항목 | 값 |
|---|---|
| dbt 프로젝트 객체 | `DBT_DEV.NATIVE.SNOWFLAKE_DBT_NATIVE` (소유자 `DBT_APP`) |
| 모델 결과 위치 | `DBT_DEV.NATIVE_TEST` |
| 실행 롤 | `DBT_APP` (`dbt_projects_profiles.yml`의 `role`) |
| 접속 계정 | `SVC_DBT` (롤 `DBT_APP`만 부여) |
| 웨어하우스 | `DBT_WH` |
| dbt 버전 | 기본값 `1.9.4` (어댑터 `1.9.2`) |
| 원천 | `SNOWFLAKE_SAMPLE_DATA.TPCH_SF1` (공유 DB) |

## 저장소 구조

```
dbt-snowflake-native/
├── dbt/                          Snowflake로 올라가는 부분 (배포 대상은 이 디렉토리뿐)
│   ├── dbt_project.yml
│   ├── dbt_projects_profiles.yml
│   └── models/
├── setup/                        Snowflake 쪽 준비 SQL (배포 대상 아님)
│   ├── 01-native-setup.sql
│   ├── 02-native-ownership.sql
│   ├── 03-native-task-grants.sql
│   └── 04-native-task.sql
├── scripts/                      로컬 실행 스크립트 (배포 대상 아님)
│   ├── add-connection.sh
│   └── run-native.sh
├── .gitlab-ci.yml
└── README.md
```

| 경로 | 내용 |
|---|---|
| `dbt/` | dbt 프로젝트. `dbt-snowflake-ci`와 같은 모델이다. `snow dbt deploy --source dbt`가 이 디렉토리만 올린다 |
| `dbt/dbt_projects_profiles.yml` | Snowflake 안에서 쓰는 프로필. `profiles.yml`보다 우선한다. 계정 정보와 비밀번호가 없다 |
| `setup/01-native-setup.sql` | 프로젝트 객체를 둘 스키마와 최초 생성 권한 |
| `setup/02-native-ownership.sql` | 관리자가 처음 배포한 프로젝트 객체의 소유권을 `DBT_APP`에 넘긴다 |
| `setup/03-native-task-grants.sql` | 태스크 실행에 필요한 권한(`CREATE TASK`, `EXECUTE TASK`). 관리자가 한 번 실행한다 |
| `setup/04-native-task.sql` | 프로젝트를 실행하는 태스크를 만든다. `DBT_APP` 연결(CLI)로 실행한다 |
| `scripts/add-connection.sh` | CLI 연결 `dbt_app`을 `~/.snowflake/connections.toml`에 만든다. 비밀번호는 숨김 입력 |
| `scripts/run-native.sh` | 배포와 실행을 한 번에 한다. 임시 연결을 쓰고 비밀번호를 항상 새로 묻는다 |
| `.gitlab-ci.yml` | 수동 실행 작업 하나. 배포와 실행을 한다 |

## 1. 준비

### Snowflake

`dbt-snowflake-ci` 프로젝트의 `setup/01-dbt-setup.sql`(롤, 웨어하우스, DB, 서비스 계정)이 먼저 적용되어 있어야 한다. 이어서 Snowsight에서 `ACCOUNTADMIN`으로 `setup/01-native-setup.sql`을 실행한다.

```sql
USE ROLE ACCOUNTADMIN;

CREATE SCHEMA IF NOT EXISTS DBT_DEV.NATIVE;

GRANT USAGE ON SCHEMA DBT_DEV.NATIVE TO ROLE DBT_APP;
```

`DBT_APP`에는 `CREATE DBT PROJECT` 권한을 주지 않는다. 프로젝트 객체는 관리자가 처음 한 번 만들고 소유권만 넘긴다. 그 절차는 "3. 권한"에 있다.

### 로컬

```bash
# 가상환경 생성 및 활성화
python3 -m venv .venv && source .venv/bin/activate

# Snowflake CLI 설치
pip install snowflake-cli

# 설치 확인
snow --version
```

## 2. 배포와 실행

### 스크립트로 실행

계정 식별자와 유저는 환경변수(`SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`)에서 읽는다. 없으면 스크립트가 물어본다. 비밀번호는 항상 숨김 입력으로 받는다.

```bash
# 배포와 실행(build)을 한 번에 한다. 비밀번호를 물어본다
scripts/run-native.sh

# 배포만 / 실행만
scripts/run-native.sh deploy
scripts/run-native.sh execute
```

### 연결 설정을 만들어 실행

```bash
# 연결 dbt_app을 만든다 (비밀번호 입력, 파일 권한 600)
scripts/add-connection.sh

# 연결 확인
snow connection test -c dbt_app

# 배포 (dbt/ 디렉토리의 파일이 업로드됨)
snow dbt deploy snowflake_dbt_native --source dbt --profiles-dir dbt --default-target dev -c dbt_app

# Snowflake 안에서 dbt build 실행
snow dbt execute -c dbt_app snowflake_dbt_native build
```

- **연결 옵션은 dbt 명령(`build`)보다 앞에 둔다.** `snow dbt execute`는 dbt 명령 뒤의 인자를 전부 dbt로 넘긴다. 뒤에 두면 `Connection default is not configured` 오류가 난다.
- **`--force`는 평소에 쓰지 않는다.** `--force`는 `CREATE OR REPLACE`라서 객체의 모든 버전과 실행 이력을 지운다. 코드 변경은 `--force` 없이 같은 명령을 다시 실행하면 기존 객체의 live 버전에 반영된다.

## 3. 권한 (최소 권한 원칙)

### 원칙

| 원칙 | 적용 |
|---|---|
| 접속 계정은 사람이 아닌 서비스 계정 하나, 롤도 하나 | `SVC_DBT`에는 `DBT_APP`만 부여한다 |
| 서비스 계정에 만들기 권한을 주지 않는다 | 프로젝트 객체는 관리자가 만들고 `OWNERSHIP`만 넘긴다. `CREATE DBT PROJECT`는 주지 않는다 |
| 평소 배포는 객체의 소유권으로만 한다 | `OWNERSHIP`이 있으면 live 버전을 교체할 수 있다 |
| 원천은 읽기만 한다 | 공유 DB는 `IMPORTED PRIVILEGES`만 준다 |
| 관리자 권한은 사람이 Snowsight에서만 쓴다 | 자동화 계정에는 관리자 롤을 주지 않는다 |

### 확인한 권한

`DBT_APP`이 실제로 쓴 권한이다. 배포와 실행이 이 권한만으로 통과했다.

| 대상 | 권한 | 용도 |
|---|---|---|
| 웨어하우스 `DBT_WH` | `USAGE` | 컴파일과 모델 실행 |
| 데이터베이스 `DBT_DEV` | `USAGE`, `CREATE SCHEMA` | 모델 결과 스키마(`NATIVE_TEST`)를 dbt가 만든다 |
| 스키마 `DBT_DEV.NATIVE` | `USAGE` | 프로젝트 객체가 있는 스키마를 연다 |
| 프로젝트 객체 | `OWNERSHIP` | 배포(live 버전 교체)와 실행 |
| `SNOWFLAKE_SAMPLE_DATA` | `IMPORTED PRIVILEGES` | 공유 DB 읽기 |

### 프로젝트 객체를 만드는 방법

**관리자가 만들고 소유권만 넘기는 방식을 권장한다.** 서비스 계정에 만들기 권한을 줬다가 회수할 필요가 없다.

1. 관리자 연결로 첫 배포를 한다. `ACCOUNTADMIN`이 `DBT_DEV.NATIVE` 스키마를 만든 롤이라 객체를 만들 수 있다.
2. `setup/02-native-ownership.sql`로 소유권을 `DBT_APP`에 넘긴다.
3. 이후 CI와 스크립트는 `DBT_APP`으로 `snow dbt deploy`를 `--force` 없이 실행한다. 소유권만으로 live 버전을 교체하고 실행한다.

```sql
USE ROLE ACCOUNTADMIN;

GRANT OWNERSHIP ON DBT PROJECT DBT_DEV.NATIVE.SNOWFLAKE_DBT_NATIVE TO ROLE DBT_APP COPY CURRENT GRANTS;
```

확인한 것과 못 한 것을 구분한다.

| 항목 | 상태 |
|---|---|
| 만들기 권한 없이 소유권만으로 같은 이름 재배포 | **확인함.** `DBT_APP`이 `CREATE DBT PROJECT`를 회수당한 상태에서 `Successfully deployed new files to the live version.`로 성공했다 |
| 관리자 첫 배포와 소유권 이전(`GRANT OWNERSHIP ON DBT PROJECT`) | **확인하지 못함.** 문서를 근거로 쓴 절차다. 이 계정의 현재 객체는 `DBT_APP`이 직접 만든 것이다 |

### 문서에는 있지만 시험하지 않은 최소 권한 구성

| 구성 | 내용 |
|---|---|
| 배포 롤과 실행 롤 분리 | 배포 롤은 객체 `OWNERSHIP`만 갖고, 실행 롤은 객체 `USAGE`와 데이터 권한을 갖는다. 산출물을 읽는 롤에는 `MONITOR`도 준다 |
| 컴파일 단계 분리 | `--no-auto-compile`로 배포 시 컴파일을 건너뛰면 배포 롤이 데이터 접근 권한을 가질 필요가 없다 |
| 결과 스키마를 미리 만들기 | `DBT_DEV`의 `CREATE SCHEMA` 대신 스키마를 관리자가 만들고 `DBT_APP`에는 객체 생성 권한만 준다 |

실행 권한 모델도 알아둘 만하다. dbt는 프로필 `role`의 권한으로 실행되지만, 호출한 사용자가 가진 권한 범위 안으로 제한된다. 그래서 호출 계정과 프로필 롤이 모두 웨어하우스, 데이터베이스, 스키마, 모델이 참조하는 객체에 접근할 수 있어야 한다.

## 4. GitLab CI

`.gitlab-ci.yml`의 `snowflake_native` 작업은 `main`에서 **배포 대상 파일이 바뀐 푸시일 때만 자동으로** 돈다.

| 조건 | 동작 |
|---|---|
| `main` 푸시에서 `dbt/**` 또는 `.gitlab-ci.yml`이 바뀜 | 자동 실행 |
| `main` 푸시에서 그 외 파일만 바뀜(README, `setup/`, `scripts/`) | 수동 실행 버튼만 보이고 파이프라인을 막지 않는다 |
| 다른 브랜치, MR | 파이프라인을 만들지 않는다 |

- **MR 파이프라인을 만들지 않는 이유:** 프로젝트 객체가 하나라서 MR 코드를 배포하면 live 버전이 덮어써진다.
- **`resource_group`:** 같은 객체에 배포가 겹치지 않게 한 번에 하나만 돈다.
- **`timeout`:** 15분이다.

CI 변수 설정은 이렇다.

| 변수 | 값 | 설정 |
|---|---|---|
| `SNOWFLAKE_ACCOUNT` | `<org>-<account>` | Masked |
| `SNOWFLAKE_USER` | 서비스 계정 이름 | Masked |
| `SNOWFLAKE_PASSWORD` | 비밀번호 | Masked and hidden(저장 후 값을 다시 볼 수 없다) |

프로젝트를 공개할 때는 `Settings > CI/CD > General pipelines`의 공개 파이프라인(Public pipelines)을 끈다. 켜 두면 작업 로그를 누구나 본다. 이 파이프라인은 MR에서 돌지 않고 `main`에서만 돌아서 `Protected`를 켜도 된다.

2026-10-18 확인: `.gitlab-ci.yml`이 바뀐 푸시에서 작업이 자동으로 실행되어 성공했다(66초). README만 바꾼 푸시에서는 자동 실행 없이 수동 실행 버튼만 만들어지는지 이어서 확인한다.

| 항목 | 내용 |
|---|---|
| 이미지 | `python:3.12-slim`. 작업 안에서 `pip install snowflake-cli`로 CLI를 설치한다 |
| 인증 | 프로젝트 CI 변수 `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_PASSWORD`를 CLI가 환경변수로 읽는다. 코드와 이력에는 값이 없다 |
| 배포 | `snow dbt deploy ... --source dbt --git-commit "$CI_COMMIT_SHA" --git-branch "$CI_COMMIT_REF_NAME"`. 어느 커밋이 배포됐는지 객체에 남는다 |
| 실행 | `snow dbt execute <연결 옵션> snowflake_dbt_native build` |

2026-10-18에 수동으로 실행해 성공했다(총 69초, `Done. PASS=15`). 단계별 시간은 다음과 같다.

| 단계 | 시간 |
|---|---|
| 파드 시작 | 약 4초 |
| `pip install snowflake-cli` | 약 19.5초 |
| `snow dbt deploy` (파일 9개 업로드, 자동 컴파일 포함) | 약 22초 |
| `snow dbt execute ... build` (dbt 실행 자체는 약 6.7초) | 약 21초 |

`dbt-snowflake-ci`의 파이프라인(68초)과 작업량이 다르다. 그쪽은 개발과 운영 두 환경에서 `run`과 `test`를 하고, 이쪽은 한 환경에서 배포와 `build`를 한다.

## 5. 시험 결과

2026-10-18, 로컬에서 확인했다.

| 항목 | 결과 |
|---|---|
| 기능 활성 | 이 계정에서 `snow dbt deploy`로 프로젝트 객체가 만들어졌다 |
| 실행 | `snow dbt execute ... build`가 Snowflake 안에서 성공했다. 모델 5개와 테스트 10개, 합계 15개가 모두 통과했다. dbt 실행 시간은 6.69초 |
| 임시 연결의 비밀번호 | `SNOWFLAKE_PASSWORD` 환경변수를 읽었다 |
| 재배포 | `--force` 없이 같은 이름으로 배포하면 live 버전이 교체된다 |
| 만들기 권한 회수 후 재배포 | 성공했다. 소유권만으로 충분하다 |
| 다이내믹 테이블, 증분 모델 | 둘 다 생성되었다 |
| 다이내믹 테이블 갱신 모드 | `FULL`이다. 원천이 공유 DB라서 변경 추적을 켤 수 없어 증분 갱신이 안 된다 |
| 실행 산출물 | 실행 롤이 `DBT_DEV.NATIVE`에 `dbt_project_output_stage_...` 스테이지를 소유한다 |
| 태스크 실행 | `DBT_APP`이 소유한 태스크가 `EXECUTE DBT PROJECT ... build`를 수동 1회 실행해 성공했다(18초). 쿼리 이력의 실행 사용자는 `SYSTEM`, 롤은 `DBT_APP`이다. 사람이 `DBT_APP` 세션을 쓰지 않아도 Snowflake가 직접 실행한다 |

## 6. 알려진 이슈

- **연결 옵션이 dbt 명령 뒤에 있으면 기본 연결을 찾는다.** `snow dbt execute`에서 옵션은 `build`보다 앞에 둔다.
- **터미널에 남은 옛 비밀번호가 쓰인다.** 환경변수 `SNOWFLAKE_PASSWORD`가 이미 있으면 스크립트가 그 값을 그대로 쓴다. 비밀번호를 바꾼 뒤 `Incorrect username or password`가 나면 이것부터 의심한다. `run-native.sh`는 이제 항상 새로 묻는다.
- **공유 DB를 원천으로 쓰면 다이내믹 테이블이 항상 전체 갱신이다.** 직접 소유한 테이블이어야 증분 갱신이 가능하다.

## 7. 확인하지 않은 것

- 지원하는 dbt 버전 목록과 제한 사항, `--dbt-version`으로 올렸을 때의 동작, 배포 옵션이 기존 객체에 바뀌어 적용되는지.
- `TASK`의 주기 실행(수동 1회만 확인했다), 환경 분리(`env.yml`), Slim CI, 실행 이력 모니터링 설정, 실패 알림.
- CI 인증 방식. 지금은 비밀번호이고 PAT, OIDC도 검토 대상이다.
- 증분 모델의 두 번째 실행 결과.
- 위 "시험하지 않은 최소 권한 구성"에 적은 항목과, 관리자가 객체를 처음 만들고 소유권을 넘기는 절차.
- 일부 기능에 필요한 `live` 버전 객체 조건(`2026_06` 동작 변경 번들).

## 8. Python 방식과 비교

`dbt-snowflake-ci`(dbt-core를 CI 파드에서 실행)와 이 프로젝트(dbt 프로젝트 객체를 Snowflake 안에서 실행)를 같은 모델로 비교했다. 목표는 "dbt 결과 객체를 사용자가 Snowsight에서 쿼리로 바꾸지 못하게 하고, 변경은 배포한 프로젝트를 통해서만 한다"는 통제다.

### 가장 큰 차이

dbt 코드가 Snowflake 안에서 **객체**로 존재하는지가 가장 큰 차이다.

| | Python(dbt-core, CI 파드) | Snowflake CLI(dbt 프로젝트 객체) |
|---|---|---|
| Snowflake가 보는 것 | 서비스 계정이 보내는 평범한 SQL(`CREATE VIEW ...`) | `DBT PROJECT` 객체와 소유자, 버전, 실행 이력 |
| 코드가 있는 곳 | GitLab과 CI 파드 | GitLab과 Snowflake 안(live 버전) |
| 실행하는 곳 | CI 파드가 접속해서 SQL을 보낸다 | Snowflake 안에서 `EXECUTE DBT PROJECT`로 돈다 |
| 실행 권한 통제 | 자격증명을 가진 쪽은 SQL을 무엇이든 보낼 수 있다 | 객체 권한(`USAGE`, `MONITOR`, `OWNERSHIP`)으로 나눈다 |
| 변경 경로 | CI 파이프라인 | `snow dbt deploy`로 live 버전을 교체 |
| 실행 시 CI 자격증명 | 매번 필요하다 | 배포할 때만 필요하다. 태스크로 돌리면 실행에는 불필요하다(시험 전) |
| dbt 버전 | 이미지나 설치로 자유롭게 고른다 | Snowflake가 제공하는 버전. 기본값 `1.9.4` |

### UI에 dbt 프로젝트가 하나만 보이는 이유

Snowsight의 dbt 화면은 `DBT PROJECT` 객체만 보여 준다. Python 방식으로 만든 뷰와 테이블(`DBT_DEV.DEV`, `DBT_PROD.MART`)은 Snowflake에게 `DBT_APP`이 SQL로 만든 일반 객체다. 결과물은 둘 다 뷰와 테이블이지만 출처를 기록하는 방식이 다르다.

Python 쪽 객체에서도 흔적은 남는다. 다이내믹 테이블 정의 끝에 `/* {"app": "dbt", "dbt_version": ..., "node_id": ...} */`라는 dbt 쿼리 주석이 붙어 있었다. dbt가 만들었다는 것은 알 수 있지만 어느 배포 버전에서 나왔는지는 Snowflake에서 알 수 없다.

### 통제 관점

두 방식 모두 결과 객체의 소유자는 `DBT_APP`이다. 사용자가 쿼리로 객체를 바꾸지 못하게 하는 기본 조건은 사람에게 `DBT_APP`을 주지 않는 것이고, 사람은 `DBT_USER`(조회 전용)만 갖는다. 이 부분은 두 방식이 같다.

| 관점 | Python | CLI(네이티브) |
|---|---|---|
| 객체를 바꾸는 경로 | 파이프라인. 자격증명이 새면 같은 권한으로 SQL을 보낼 수 있다 | 배포(소유권)와 실행(`EXECUTE DBT PROJECT`) |
| 코드와 결과의 연결 | 쿼리 주석뿐 | 객체의 버전과 실행 이력 |
| 배포 계정의 권한 | 대응하는 개념이 없다 | 새 프로젝트 객체를 만들 수 없고 기존 객체의 소유권으로 내용만 교체하게 할 수 있다(시험함) |

### 주의할 점

- 네이티브라고 해서 사람이 SQL로 객체를 못 바꾸는 것이 자동으로 보장되지는 않는다. 결과 객체는 여전히 `DBT_APP` 소유이고, `DBT_APP`을 쓸 수 있는 쪽은 SQL로 바꿀 수 있다.
- 문서에 따르면 `EXECUTE DBT PROJECT`는 프로필 롤의 권한으로 돌지만 호출한 사용자의 권한 범위 안으로 제한된다. 호출자도 해당 스키마 권한이 필요하므로, 사람이 실행만 하고 객체는 못 건드리게 하는 분리가 수동 실행으로는 깔끔하지 않을 수 있다.
- 태스크는 소유자 롤 권한으로 돈다. 그래서 사람에게 `DBT_APP`을 주지 않고도 스케줄 실행이 가능한지가 핵심 시험 항목이다(`setup/03`, `04`).
- 서비스 계정(`SVC_DBT`)이 비밀번호 인증이라 자격증명이 있으면 `DBT_APP`으로 임의 SQL을 보낼 수 있다. 이 위험은 두 방식이 같다. 접속 출처를 CI로 제한하는 네트워크 정책이나 PAT, OIDC가 대안이지만 시험하지 않았다.

### 정리

| 축 | 평가 |
|---|---|
| 감사와 추적 | 네이티브가 낫다. 객체, 버전, 실행 이력이 Snowflake 안에 남는다 |
| 권한 분리 | 네이티브가 더 세밀하다(소유권과 실행 분리). 호출자 권한 제약이 있어 태스크 구성으로 검증해야 한다 |
| 유연성 | Python이 높다. dbt 버전과 패키지를 자유롭게 고른다 |
| 단순함 | Python이 낫다 |

### 태스크 시험 계획

1. 관리자가 `setup/03-native-task-grants.sql`을 Snowsight에서 실행한다.
2. `snow sql -c dbt_app -f setup/04-native-task.sql`로 태스크를 만들고 한 번 수동 실행한다. 태스크는 만들면 정지 상태라서 스케줄은 켜지 않는다.
3. 태스크 실행 이력에서 성공 여부와 실행 주체를 확인한다. 사람이 `DBT_APP`을 쓰지 않아도 실행되는지가 확인 대상이다.

결과(2026-10-18): 태스크가 `SUCCEEDED`로 끝났고, 쿼리 이력에서 실행 사용자는 `SYSTEM`, 롤은 `DBT_APP`이었다. 이 구성이면 사람에게 `DBT_APP`을 주지 않고도 스케줄 실행이 가능하다. 태스크 생성도 `snow sql`(CLI)로 했고 Snowsight에서 쿼리로 바꾸지 않았다. 필요한 권한은 `DBT_APP`의 `CREATE TASK ON SCHEMA`와 `EXECUTE TASK ON ACCOUNT`였다. 실행 시 `NATIVE_TEST`의 뷰, 테이블, 증분 테이블이 갱신되었고 다이내믹 테이블은 갱신되지 않았다(정의가 그대로라서 dbt가 건드리지 않았다).

## 9. 다음 단계

1. 배포 시간을 줄인다. `--no-auto-compile`(배포 중 컴파일 약 14초)과 CLI가 미리 설치된 이미지(설치 약 19.5초)를 시험한다.
2. 배포 롤과 실행 롤을 분리하고 `--no-auto-compile`을 시험한다.
3. `TASK`로 주기 실행하고 모니터링을 켠다.
4. 인증을 비밀번호에서 PAT나 OIDC, 키페어로 바꾼다.

## 라이선스

MIT. 자세한 내용은 [LICENSE](LICENSE)를 본다.
