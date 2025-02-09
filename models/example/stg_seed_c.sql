{{ config(tag='snap_join_example') }}

SELECT
        *
FROM
        {{ ref('seed_c') }}

WHERE   1=1
