-- TASK로 dbt 프로젝트를 Snowflake가 직접 실행하게 하기 위한 권한. 관리자 연결(ACCOUNTADMIN)로 한 번 실행한다.
-- 태스크 생성과 실행은 04-native-task.sql을 DBT_APP 연결(CLI)로 실행한다.

USE ROLE ACCOUNTADMIN;

-- DBT_APP이 프로젝트 객체가 있는 스키마에 태스크를 만들 수 있게 한다
GRANT CREATE TASK ON SCHEMA DBT_DEV.NATIVE TO ROLE DBT_APP;

-- DBT_APP이 소유한 태스크를 실행하고 재개할 수 있게 한다 (계정 수준 권한)
GRANT EXECUTE TASK ON ACCOUNT TO ROLE DBT_APP;

-- 확인
SHOW GRANTS TO ROLE DBT_APP;
