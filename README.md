Welcome to the snap_join project!

### What is this?

This is a dbt macro that joins multiple snapshots into a single new snapshot.

### How to use the macro?:

Create a dbt model with the name you prefer for the resulting snapshot table or view.
This is the model code from one of the examples:
```
{{ snap_join(['stg_seed_a', 'stg_seed_b','stg_seed_c'],
             ['valid_from', 'valid_from', 'dbt_valid_from'],
             ['valid_to', 'valid_to', 'dbt_valid_to'],
             ['primary_key', 'primary_key', 'primary_key_with_another_name'],
             [['dim_a', 'dim_b', 'dim_c'], ['dim_d', 'dim_e', 'dim_f'], ['dim_g', 'dim_h']]
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
- a list of the column from each snapshot that is used in the sql join statement between the snapshots
- a list of lists with the columns you want to select from each snapshot



### How to install the macro?:
- add this code snipet to your packages.yml file: 
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
    version: 1.3.0
 ``` 
