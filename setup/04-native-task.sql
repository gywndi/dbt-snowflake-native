-- dbt 프로젝트를 Snowflake 태스크로 실행한다. DBT_APP 연결(CLI)로 실행한다.
--   snow sql -c dbt_app -f setup/04-native-task.sql
-- 03-native-task-grants.sql이 먼저 적용되어 있어야 한다.

-- 프로젝트 객체와 같은 스키마에 태스크를 만든다. 태스크는 소유자(DBT_APP) 권한으로 돈다
CREATE OR ALTER TASK DBT_DEV.NATIVE.RUN_DBT_NATIVE
  WAREHOUSE = DBT_WH
  SCHEDULE = '60 MINUTE'
AS
  EXECUTE DBT PROJECT DBT_DEV.NATIVE.SNOWFLAKE_DBT_NATIVE ARGS = 'build --target dev';

-- 스케줄을 켜지 않고 한 번만 수동으로 실행한다 (태스크는 만들면 정지 상태다)
EXECUTE TASK DBT_DEV.NATIVE.RUN_DBT_NATIVE;

-- 상태 확인
SHOW TASKS IN SCHEMA DBT_DEV.NATIVE;
