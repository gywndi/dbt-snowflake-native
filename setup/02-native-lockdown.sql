-- 최초 배포가 끝난 뒤 실행한다. 관리자 연결(ACCOUNTADMIN)로 한 번 실행한다.
-- 프로젝트 객체는 만든 롤(DBT_APP)이 소유한다. 이후 배포는 소유권만으로 되므로 만들기 권한을 회수한다.

USE ROLE ACCOUNTADMIN;

-- DBT_APP이 새 dbt 프로젝트 객체를 만들 수 없게 한다
REVOKE CREATE DBT PROJECT ON SCHEMA DBT_DEV.NATIVE FROM ROLE DBT_APP;

-- 확인: CREATE DBT PROJECT가 없고 프로젝트 객체의 OWNERSHIP만 남아야 한다
SHOW GRANTS TO ROLE DBT_APP;
