{{ dbt_snap_join.snap_join(['stg_seed_a', 'stg_seed_b'],
                             ['valid_from', 'valid_from'],
                             ['valid_to', 'valid_to'],
                             ['unique_key', 'unique_key'],
                             [['dim_a'], ['dim_d']]
                             ) }}


SELECT
        *
FROM
        snap_join

WHERE   1=1

ORDER BY
        snap_join.unique_key ASC,
        snap_join.dbt_valid_from DESC
