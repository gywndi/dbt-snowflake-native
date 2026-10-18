-- Snowflake 안에서 dbt를 실행하기 위한 준비. 관리자 연결(ACCOUNTADMIN)로 한 번 실행한다.
-- dbt-snowflake-ci 프로젝트의 setup/01-dbt-setup.sql(롤·웨어하우스·DB)을 먼저 실행해 둔 상태를 전제로 한다.

USE ROLE ACCOUNTADMIN;

-- dbt 프로젝트 객체를 둘 스키마 (모델 결과가 들어가는 DBT_DEV.NATIVE_TEST와 분리)
CREATE SCHEMA IF NOT EXISTS DBT_DEV.NATIVE;

-- DBT_APP이 이 스키마를 열 수 있게 한다. 프로젝트 객체를 만드는 CREATE DBT PROJECT 권한은 주지 않는다
-- 객체는 관리자가 처음 한 번 배포하고, 소유권만 DBT_APP에 넘긴다 (02-native-ownership.sql)
GRANT USAGE ON SCHEMA DBT_DEV.NATIVE TO ROLE DBT_APP;

-- 확인
SHOW GRANTS TO ROLE DBT_APP;
