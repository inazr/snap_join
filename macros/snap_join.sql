{% macro snap_join(list_of_models, valid_from_columns, valid_to_columns, list_of_unique_keys, list_of_columns, incremental=false) %}

{# dbt-bigquery has no delete+insert and dbt-clickhouse has no merge #}
{% if incremental %}
{{ config(materialized='incremental', unique_key='_surrogate_key', incremental_strategy='merge' if target.type == 'bigquery' else 'delete+insert') or "" }}
{% endif %}
{% set load_changes_only = incremental and is_incremental() %}

{% set column_list_alias = [] %}
{% set column_list_labels = [] %}
{% set column_list_with_unique_key = [] %}

{# ClickHouse: LEFT JOIN fills unmatched rows with type defaults unless join_use_nulls is set, a string can't be coalesced with a date, and NULL can't be cast to String #}
{% set is_clickhouse = target.type == 'clickhouse' %}
{% set max_valid_to = "toDate32('9999-12-31')" if is_clickhouse else "'9999-12-31'" %}

{%- for model in list_of_models -%}
    {%- for column in list_of_columns[loop.index0] -%}
        {{ column_list_alias.append(model+"."+column+" AS "+model+"_"+column) or "" }}
        {{ column_list_labels.append(model+"_"+column) or "" }}
        {{ column_list_with_unique_key.append("coalesce(toString("+model+"."+column+"), '_null_')" if is_clickhouse else model+"."+column) or "" }}
    {%- endfor -%}
{% endfor -%}

{{ column_list_with_unique_key.append('valid_from_to.unique_key') or "" }}

{% set valid_from_list = [] %}
{% for model in list_of_models %}
    {{ valid_from_list.append(model+"."+valid_from_columns[loop.index0]) or "" }}
{% endfor %}
{% set is_covered = "CASE WHEN COALESCE(" ~ valid_from_list | join(", ") ~ ") IS NOT NULL THEN 1 ELSE 0 END" %}
{{ column_list_with_unique_key.append(is_covered) or "" }}

WITH
{% if load_changes_only %}
_anchors AS (

    SELECT
            unique_key,
            MAX(dbt_valid_from) AS anchor
    FROM
            {{ this }}
    GROUP BY
            unique_key

),

_changed_keys AS (

    SELECT DISTINCT
            source_dates.unique_key,
            _anchors.anchor
    FROM (

        {% for model in list_of_models %}
        SELECT
                {{ list_of_unique_keys[loop.index0] }} AS unique_key,
                {{ valid_from_columns[loop.index0] }} AS valid_from,
                {{ valid_to_columns[loop.index0] }} AS valid_to
        FROM
                {{ ref(model) }}

        {% if not loop.last %}
        UNION ALL
        {% endif -%}

        {% endfor %}
    ) AS source_dates

    LEFT JOIN
            _anchors
       ON   source_dates.unique_key = _anchors.unique_key

    WHERE
            _anchors.anchor IS NULL
       OR   source_dates.valid_from > _anchors.anchor
       OR   source_dates.valid_to > _anchors.anchor

    {% if is_clickhouse %}
    SETTINGS join_use_nulls = 1
    {% endif %}
),

{% endif %}
{% for model in list_of_models %}
{{ model }} AS (

    {% if not load_changes_only %}
    SELECT
            *
    FROM
            {{ ref(model) }}
    {% else %}
    {# ref() can render as an aliased subquery, e.g. with --empty, so it can't take an alias directly #}
    {# A row ending on the anchor adds no values, but it can be the only source of the anchor's boundary #}
    SELECT
            source_rows.*
    FROM (

        SELECT
                *
        FROM
                {{ ref(model) }}

    ) AS source_rows

    INNER JOIN
            _changed_keys
       ON   source_rows.{{ list_of_unique_keys[loop.index0] }} = _changed_keys.unique_key

    WHERE
            _changed_keys.anchor IS NULL
       OR   source_rows.{{ valid_to_columns[loop.index0] }} IS NULL
       OR   source_rows.{{ valid_to_columns[loop.index0] }} >= _changed_keys.anchor
    {% endif %}

),

{% endfor %}
all_valid_from AS (

    {% for model in list_of_models %}

    SELECT
            {{ model }}.{{ valid_from_columns[loop.index0] }} AS dbt_valid_from,
            {{ model }}.{{ list_of_unique_keys[loop.index0] }} AS unique_key
    FROM
            {{ model }}

    UNION ALL

    SELECT
            {{ model }}.{{ valid_to_columns[loop.index0] }} AS dbt_valid_from,
            {{ model }}.{{ list_of_unique_keys[loop.index0] }} AS unique_key
    FROM
            {{ model }}
    WHERE
            {{ model }}.{{ valid_to_columns[loop.index0] }} IS NOT NULL

    {% if not loop.last %}
        UNION ALL
    {% endif -%}

    {% endfor %}
)

,   all_distinct_valid_from AS (

    SELECT DISTINCT
            all_valid_from.dbt_valid_from,
            all_valid_from.unique_key
    FROM
            all_valid_from

    {% if load_changes_only %}
    INNER JOIN
            _changed_keys
       ON   all_valid_from.unique_key = _changed_keys.unique_key

    WHERE
            _changed_keys.anchor IS NULL
       OR   all_valid_from.dbt_valid_from >= _changed_keys.anchor
    {% endif %}

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
            {{ is_covered }} AS _is_covered,
            {{ dbt_utils.generate_surrogate_key(column_list_with_unique_key) }} AS _row_hash
    FROM
            valid_from_to

    {% for model in list_of_models -%}

    LEFT JOIN
            {{ model }}
       ON   valid_from_to.unique_key = {{ model }}.{{ list_of_unique_keys[loop.index0] }}
      AND   valid_from_to.dbt_valid_from >= {{ model }}.{{ valid_from_columns[loop.index0] }}
      AND   valid_from_to.dbt_valid_from < COALESCE({{ model }}.{{ valid_to_columns[loop.index0] }}, {{ max_valid_to }})

    {% endfor %}

    {% if is_clickhouse %}
    SETTINGS join_use_nulls = 1
    {% endif %}
)

,   change_flags AS (

    SELECT
            joining_data.*,
            CASE WHEN joining_data._row_hash = LAG(joining_data._row_hash) OVER (PARTITION BY joining_data.unique_key ORDER BY joining_data.dbt_valid_from ASC)
                 THEN 0
                 ELSE 1
            END AS _is_change
    FROM
            joining_data

)

,   islands AS (

    SELECT
            change_flags.*,
            SUM(change_flags._is_change) OVER (PARTITION BY change_flags.unique_key ORDER BY change_flags.dbt_valid_from ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS _island
    FROM
            change_flags

)

,   snap_join AS (

    SELECT
            MIN(islands.dbt_valid_from) AS dbt_valid_from,
            CASE WHEN COUNT(*) = COUNT(islands.dbt_valid_to) THEN MAX(islands.dbt_valid_to) END AS dbt_valid_to,
            islands.unique_key,
            {{ column_list_labels | join(",\n            ") }},
            {{ dbt_utils.generate_surrogate_key(['islands.unique_key', 'MIN(islands.dbt_valid_from)']) }} AS _surrogate_key
    FROM
            islands

    GROUP BY
            islands.unique_key,
            islands._island,
            islands._is_covered,
            {{ column_list_labels | join(",\n            ") }}

    HAVING
            islands._is_covered = 1

)
{% endmacro %}
