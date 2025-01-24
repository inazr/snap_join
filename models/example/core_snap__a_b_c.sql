{{ snap_join(['stg_seed_a', 'stg_seed_b','stg_seed_c'],
             ['valid_from', 'valid_from', 'dbt_valid_from'],
             ['valid_to', 'valid_to', 'dbt_valid_to'],
             ['primary_key', 'primary_key', 'primary_key_with_another_name'],
             [['dim_a', 'dim_b', 'dim_c'], ['dim_d', 'dim_e', 'dim_f'], ['dim_a', 'dim_h']]
             ) }}

SELECT
        *
FROM
        snap_join

WHERE   1=1

ORDER BY
        snap_join.join_key ASC,
        snap_join.valid_from DESC
