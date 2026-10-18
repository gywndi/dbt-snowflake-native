-- 뷰: 조회할 때마다 원천을 읽어 계산한다. 항상 최신이다. (CREATE SCHEMA 회수 후 CI 검증용 변경)
{{ config(materialized='view') }}

select
    o_orderstatus as order_status,
    count(*) as order_count,
    count(distinct o_custkey) as customer_count
from {{ source('tpch', 'orders') }}
group by o_orderstatus
