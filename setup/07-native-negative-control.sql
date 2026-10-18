-- 대조군: 미리 만들지 않은 스키마를 쓰면 CREATE SCHEMA 권한 에러로 실패하는지 본다. 관리자 연결(ACCOUNTADMIN)로 실행한다.
-- 06 적용 후, 이 파일로 결과 스키마를 없애고 파이프라인을 다시 돌린다. 검증 후 05를 다시 실행해 원복한다.

USE ROLE ACCOUNTADMIN;

-- 결과 스키마 제거 (dbt가 없는 스키마를 만들려다 CREATE SCHEMA 권한 에러가 나야 한다)
DROP SCHEMA IF EXISTS DBT_DEV.NATIVE_TEST;
