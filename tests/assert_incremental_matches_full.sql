{{ config(tags='snap_join_example') }}

{{ dbt_utils.test_equality(ref('core_snap__a_b_c_incremental'), compare_model=ref('core_snap__a_b_c')) }}
