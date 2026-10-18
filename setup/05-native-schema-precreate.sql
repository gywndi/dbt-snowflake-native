-- DBT_APP의 DB 수준 CREATE SCHEMA 없이 dbt를 돌리기 위한 준비. 관리자 연결(ACCOUNTADMIN)로 실행한다.
-- 모델 결과 스키마(DBT_DEV.NATIVE_TEST)를 관리자가 미리 만들고, DBT_APP에는 스키마 안의 권한만 준다.
-- 현재 NATIVE_TEST는 DBT_APP이 dbt로 만든 것이라 DBT_APP이 소유한다. 소유권이 남아 있으면 검증이 왜곡되므로 지우고 다시 만든다.

USE ROLE ACCOUNTADMIN;

-- 기존 결과 스키마를 지운다 (데모 모델 결과뿐이라 dbt가 다시 채운다)
DROP SCHEMA IF EXISTS DBT_DEV.NATIVE_TEST;

-- 관리자가 소유하는 스키마로 다시 만든다
CREATE SCHEMA DBT_DEV.NATIVE_TEST;

-- 스키마를 열고, 모델 종류별 객체를 만들 수 있게 한다 (demo 모델: view, table, incremental, dynamic table)
GRANT USAGE ON SCHEMA DBT_DEV.NATIVE_TEST TO ROLE DBT_APP;
GRANT CREATE VIEW, CREATE TABLE, CREATE DYNAMIC TABLE ON SCHEMA DBT_DEV.NATIVE_TEST TO ROLE DBT_APP;

-- 확인: DBT_APP의 권한 목록
SHOW GRANTS TO ROLE DBT_APP;
