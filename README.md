## Welcome to the snap_join macro project!
[![dbt - >=1.8.0](https://img.shields.io/static/v1?label=dbt&message=>%3D1.8.0&color=%23FF694B&logo=dbt)](https://getdbt.com)

### What is this?

This is a dbt macro that joins multiple SCD2 tables into a single new SCD2 table. It runs on dbt snapshots and on any other SCD2 table, and you can mix both in one join.

### Databases:

[![db - BigQuery](https://img.shields.io/static/v1?label=db&message=BigQuery&color=%23669DF6&logo=googlebigquery)](https://cloud.google.com/bigquery)
[![db - ClickHouse](https://img.shields.io/static/v1?label=db&message=ClickHouse&color=%23FFCC01&logo=clickhouse)](https://clickhouse.com)
[![db - Databricks](https://img.shields.io/static/v1?label=db&message=Databricks&color=%23FF3621&logo=databricks)](https://www.databricks.com)
[![db - duckdb](https://img.shields.io/static/v1?label=db&message=duckdb&color=%23FFF000&logo=duckdb)](https://motherduck.com)
[![db - Redshift](https://img.shields.io/static/v1?label=db&message=Redshift&color=%238C4FFF)](https://aws.amazon.com/redshift)
[![db - Snowflake](https://img.shields.io/static/v1?label=db&message=Snowflake&color=%2329B5E8&logo=Snowflake)](https://www.snowflake.com)


### What is an SCD2 table?

An SCD2 (slowly changing dimension type 2) table stores the state of an entity identified as "abc" at a specific point in time.
Each record has a valid_from and a valid_to value. A dbt snapshot is an SCD2 table that dbt builds for you, with the columns `dbt_valid_from` and `dbt_valid_to`.

| valid_from |  valid_to   | unique_key |  dim_a |  dim_b |
| ---------- | ----------- |------------| ------ | ------ |
| 2025-01-04 |             | abc        |  low   |  blue  |
| 2025-01-02 |  2025-01-04 | abc        |  high  |  blue  |
| 2025-01-01 |  2025-01-02 | abc        |  high  |  red   |

### Features of this macro:

- The resulting snapshot will be reduced to the minimum number of records needed to represent the state of any given column set. If you join two tables the number of records in the output snapshot depends on the selected column set.
- The same column name can appear in several source tables, because each output column is named after its source model.
- You can join as many source snapshots into a single output snapshot as you like.
- There are no naming restrictions for any column. e.g. the column that represents the valid_from point in time can be named `valid_from` in one of the tables and `dbt_valid_from` in any of the other source tables.


### How to use the macro?

Create a dbt model with the name you prefer for the resulting snapshot table or view.
This is the model code from one of the examples:
```
{{ dbt_snap_join.snap_join(['stg_seed_a', 'stg_seed_b','stg_seed_c'],
                           ['valid_from', 'valid_from', 'dbt_valid_from'],
                           ['valid_to', 'valid_to', 'dbt_valid_to'],
                           ['unique_key', 'unique_key', 'unique_key_with_another_name'],
                           [['dim_a', 'dim_b', 'dim_c'], ['dim_d', 'dim_e', 'dim_f'], ['dim_a', 'dim_h']]) }}

SELECT
        *
FROM
        snap_join

WHERE   1=1

ORDER BY
        snap_join.unique_key ASC,
        snap_join.dbt_valid_from DESC
 ``` 

The snap_join macro takes 5 arguments:
- a list of all the snapshot models you want to join
- a list of the valid_from column from each snapshot
- a list of the valid_to column from each snapshot
- a list of the unique_key column from each snapshot
- a list of lists with the columns you want to select from each snapshot
- optional: `incremental=true` to only process changes on later runs

The macro returns these columns:

| Column           | Description                                                     |
| ---------------- | --------------------------------------------------------------- |
| dbt_valid_from   | Start of the period                                             |
| dbt_valid_to     | End of the period, NULL for the current record                  |
| unique_key       | The key shared by the source tables                             |
| \<model>_\<column> | Each selected column, e.g. `stg_seed_a_dim_a`                   |
| _surrogate_key   | Primary key of the output, built from unique_key and dbt_valid_from |

### How to run the macro incrementally?

Add `incremental=true` to the macro call. You don't need a `config()` block, because the macro sets the materialization, the `unique_key` and the strategy (`merge` on BigQuery, `delete+insert` on all others). To change these settings, put your `config()` block after the macro call, because a block before it gets overridden.
```
{{ dbt_snap_join.snap_join(['stg_seed_a', 'stg_seed_b'],
                           ['valid_from', 'valid_from'],
                           ['valid_to', 'valid_to'],
                           ['unique_key', 'unique_key'],
                           [['dim_a'], ['dim_d']],
                           incremental=true) }}

SELECT
        *
FROM
        snap_join
 ``` 

On later runs, the macro only processes keys with a source date after their most recent output row. It replaces that row and adds the new ones, and older rows stay as they are.

This assumes your sources only add newer data. Run `dbt run --full-refresh` periodically to pick up what an incremental run misses:
- changes dated before a key's most recent output row, e.g. late data from a source that loads less often
- corrections to existing source rows
- keys removed from all sources

Incremental mode has only been tested on DuckDB so far. Version 1.0.0 will follow once it has been tested on all supported databases.

### How to install the macro?
- add this code snippet to your packages.yml file: 
```
packages:
  - git: "https://github.com/inazr/snap_join"
    revision: v0.5.0-beta
 ``` 

- Steps to run a test:
  - run `dbt deps`
  - enable the seeds & models in your own dbt_project.yml file:
    ```
    models:
      dbt_snap_join:
        +enabled: true

    seeds:
      dbt_snap_join:
        +enabled: true
    ```
  - run `dbt build -s tag:snap_join_example`


### Additional Requirements?
```
packages:
  - package: dbt-labs/dbt_utils
    version: [">=1.3.0"]
 ``` 
