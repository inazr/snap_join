{{ config(tag='snap_join_example') }}

SELECT
        *
FROM
        {{ ref('seed_a') }}

WHERE   1=1
