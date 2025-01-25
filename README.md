Welcome to the snap_join macro project!

### What is this?

This is a dbt macro that joins multiple snapshots into a single new snapshot.

### What is a snapshot?

A snapshot table stores the state of an enitity abc at a specific point in time. 
Each record in a snapshot table has a valid_from and a valid_to value.

| valid_from |  valid_to   |  primary_key |  dim_a |  dim_b |
| ---------- | ----------- | ------------ | ------ | ------ |
| 2025-01-01 |  2025-01-02 |  abc         |  high  |  red   |
| 2025-01-02 |  2025-01-04 |  abc         |  high  |  blue  |
| 2025-01-04 |             |  abc         |  low   |  blue  |

### Features of this macro:

- You can join as many source snapshots into a single output snapshot as you like.
- There are no naming restrictions for any column. e.g. the column that represents the valid_from point in time can be named `valid_from` in one of the tables and `dbt_valid_from` in any of the other source tables.
- The resulting snapshot will be reduced to the minimum number of records needed to represent the state of any given column set. If you join two tables the number of records in the output snapshot depends on the selected column set.
- The column name in each source table needs to be unique. But any column name can appear in any table.

### How to use the macro?:

Create a dbt model with the name you prefer for the resulting snapshot table or view.
This is the model code from one of the examples:
```
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
 ``` 

The snap_join macro takes 5 arguments:
- a list of all the snapshot models you want to join
- a list of the valid_from column from each snapshot
- a list of the valid_to column from each snapshot
- a list of the column from each snapshot that is used in the sql join statement between the source snapshots
- a list of lists with the columns you want to select from each snapshot

### How to install the macro?:
- add this code snippet to your packages.yml file: 
```
packages:
  - git: "https://github.com/inazr/snap_join"
    branch: main
 ``` 
- test it by running the following commands:
  - dbt deps
  - dbt seed
  - dbt build -s tag:snap_join_example

- delete the models/example folder

### Additional Requirements?:
```
packages:
  - package: dbt-labs/dbt_utils
    version: [">=1.3.0"]
 ``` 

- I have only tested the macro with bigquery. I would appreciate feedback on how it works with other databases.
