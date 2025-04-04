{% macro snap_join(list_of_models, valid_from_columns, valid_to_columns, list_of_unique_keys, list_of_columns) %}

{% set column_list = [] %}
{% set column_list_alias = [] %}
{% set column_list_labels = [] %}
{% set column_list_with_unique_key = [] %}

{%- for model in list_of_models -%}
    {%- for column in list_of_columns[loop.index0] -%}
        {{ column_list.append(model+"."+column) or "" }}
        {{ column_list_alias.append(model+"."+column+" AS "+model+"_"+column) or "" }}
        {{ column_list_labels.append(model+"_"+column) or "" }}
        {{ column_list_with_unique_key.append(model+"."+column) or "" }}
    {%- endfor -%}
{% endfor -%}

{{ column_list_with_unique_key.append('valid_from_to.unique_key') or "" }}

{% if target.type == 'duckdb' %}
    {% set exclude_except = 'EXCLUDE' %}
{% elif target.type == 'snowflake' %}
    {% set exclude_except = 'EXCLUDE' %}
{% elif target.type == 'bigquery' %}
    {% set exclude_except = 'EXCEPT' %}
{% endif %}

WITH
all_distinct_valid_from AS (

    {% for model in list_of_models %}

    SELECT
            {{ model }}.{{ valid_from_columns[loop.index0] }} AS dbt_valid_from,
            {{ model }}.{{ list_of_unique_keys[loop.index0] }} AS unique_key
    FROM
            {{ ref(model) }}

    {% if not loop.last %}
        UNION DISTINCT
    {% endif -%}

    {% endfor %}
)

,   valid_from_to AS (

    SELECT
            all_distinct_valid_from.dbt_valid_from,
            LEAD(all_distinct_valid_from.dbt_valid_from) OVER (PARTITION BY all_distinct_valid_from.unique_key ORDER BY all_distinct_valid_from.dbt_valid_from ASC) AS dbt_valid_to,
            all_distinct_valid_from.unique_key
    FROM
            all_distinct_valid_from

)

,   joining_data AS (

    SELECT
            valid_from_to.dbt_valid_from,
            valid_from_to.dbt_valid_to,
            valid_from_to.unique_key,
            {{ column_list_alias | join(",\n        ") }},
            CASE WHEN {{ dbt_utils.generate_surrogate_key(column_list_with_unique_key) }} = LAG({{ dbt_utils.generate_surrogate_key(column_list_with_unique_key) }}) OVER (PARTITION BY valid_from_to.unique_key ORDER BY valid_from_to.dbt_valid_from ASC)
                 THEN NULL
                 ELSE {{ dbt_utils.generate_surrogate_key(column_list_with_unique_key) }}
            END AS _surrogate_key
    FROM
            valid_from_to

    {% for model in list_of_models -%}

    LEFT JOIN
            {{ ref(model) }}
       ON   valid_from_to.unique_key = {{ model }}.{{ list_of_unique_keys[loop.index0] }}
      AND   valid_from_to.dbt_valid_from >= {{ model }}.{{ valid_from_columns[loop.index0] }}
      AND   COALESCE(valid_from_to.dbt_valid_to, '8888-12-31') <= COALESCE({{ model }}.{{ valid_to_columns[loop.index0] }}, '9999-12-31')

    {% endfor %}
)

,   surrogate_to_primary_key AS (

    SELECT
            joining_data.* {{ exclude_except }}(_surrogate_key),

        {% if target.type == 'duckdb' or target.type == 'bigquery' %}

            TO_HEX(MD5(STRING_AGG(joining_data._surrogate_key) OVER (PARTITION BY joining_data.unique_key ORDER BY joining_data.dbt_valid_from ASC))) AS _surrogate_key

        {% elif target.type == 'snowflake' %}

            HEX_ENCODE(MD5(ARRAY_TO_STRING(ARRAY_AGG(joining_data._surrogate_key) OVER (PARTITION BY joining_data.unique_key ORDER BY joining_data.dbt_valid_from ASC), ', '))) AS _surrogate_key

        {% endif %}
    FROM
            joining_data

)

,   snap_join AS (

    SELECT
            MIN(surrogate_to_primary_key.dbt_valid_from) AS dbt_valid_from,
            NULLIF(MAX(COALESCE(surrogate_to_primary_key.dbt_valid_to, '9999-12-31')), '9999-12-31') AS dbt_valid_to,
            surrogate_to_primary_key.* {{ exclude_except }}(dbt_valid_from, dbt_valid_to),
    FROM
            surrogate_to_primary_key

    GROUP BY
            surrogate_to_primary_key.unique_key,
            {{ column_list_labels | join(",\n") }},
            surrogate_to_primary_key._surrogate_key

)
{% endmacro %}
