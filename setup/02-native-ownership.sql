-- dbt 프로젝트 객체의 소유권을 DBT_APP에 넘긴다. 관리자(ACCOUNTADMIN)가 첫 배포를 마친 뒤 한 번 실행한다.
-- 첫 배포는 관리자 연결로 한다 (ACCOUNTADMIN은 DBT_DEV.NATIVE를 만든 롤이라 객체를 만들 수 있다).
--   snow dbt deploy snowflake_dbt_native --source dbt --profiles-dir dbt --default-target dev -c admin --role ACCOUNTADMIN --warehouse DBT_WH --database DBT_DEV --schema NATIVE
-- 이후 DBT_APP은 CREATE DBT PROJECT 없이 소유권만으로 내용을 교체하고 실행한다.
-- 주의: 이 소유권 이전은 문서를 근거로 쓴 것이고 실제로 실행해 보지 않았다.

USE ROLE ACCOUNTADMIN;

-- 프로젝트 객체의 소유권을 넘긴다 (기존 권한은 유지)
GRANT OWNERSHIP ON DBT PROJECT DBT_DEV.NATIVE.SNOWFLAKE_DBT_NATIVE TO ROLE DBT_APP COPY CURRENT GRANTS;

-- 확인: DBT_APP에 프로젝트 객체의 OWNERSHIP이 있고 스키마의 CREATE DBT PROJECT는 없어야 한다
SHOW GRANTS TO ROLE DBT_APP;
