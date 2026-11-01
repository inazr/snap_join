# Changelog

## v0.4.1-beta

### Fixes
- Correct the column name in the README example
- Remove a typo from the `seed_b` example data, which makes `dim_f` numeric

### Changes
- Require dbt `>=1.8.0`
- Add macro documentation and this changelog
- Document the output columns and how to enable the examples from your own project

## v0.4.0-beta

### Fixes
- Rows invalidated without a successor (e.g. hard deletes) keep their values and valid_to
- `--empty`, `alias` and ephemeral models now work

### Changes
- Portable SQL: explicit columns replace `EXCLUDE`/`EXCEPT`
- Added Redshift, Databricks and ClickHouse

### Breaking
- All `_surrogate_key` values change
- A source valid_to of `9999-12-31` is no longer returned as NULL
- Closed keys keep a non-NULL `dbt_valid_to`
