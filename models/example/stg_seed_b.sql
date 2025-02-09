{{ config(tag='snap_join_example') }}

SELECT
        *
FROM
        {{ ref('seed_b') }}

WHERE   1=1
