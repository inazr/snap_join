{% macro snap_join(list_of_models, valid_from_columns, valid_to_columns, list_of_join_keys, list_of_columns ) %}
{% set column_list = [] %}
{%- for model in list_of_models -%}
    {%- for column in list_of_columns[loop.index0] -%}
    {{ column_list.append(model+"."+column) or "" }}
    {%- endfor -%}
{% endfor -%}
WITH all_distinct_valid_from AS (
    {% for model in list_of_models %}
        SELECT
            {{ model }}.{{ valid_from_columns[loop.index0] }} AS valid_from,
            {{ model }}.{{ list_of_join_keys[loop.index0] }} AS join_key
        FROM
            {{ ref(model) }}
        {% if not loop.last %}
            UNION DISTINCT
        {% endif -%}
    {% endfor %}
)
,   valid_from_to AS (
    SELECT
            all_distinct_valid_from.valid_from,
            LEAD(all_distinct_valid_from.valid_from) OVER (PARTITION BY all_distinct_valid_from.join_key ORDER BY all_distinct_valid_from.valid_from) AS valid_to,
            all_distinct_valid_from.join_key
    FROM
            all_distinct_valid_from
)
-- Adding columns
SELECT
        valid_from_to.valid_from,
        valid_from_to.valid_to,
        valid_from_to.join_key,
        {{ column_list | join(",\n        ") }},
        CASE WHEN {{ dbt_utils.generate_surrogate_key(column_list) }} = LAG({{ dbt_utils.generate_surrogate_key(column_list) }}) OVER (PARTITION BY valid_from_to.join_key ORDER BY valid_from_to.valid_from ASC)
             THEN NULL
             ELSE {{ dbt_utils.generate_surrogate_key(column_list) }}
        END AS surrogate_key
FROM
        valid_from_to
{% for model in list_of_models -%}
LEFT JOIN
        {{ ref(model) }}
   ON   valid_from_to.join_key = {{ model }}.{{ list_of_join_keys[loop.index0] }}
  AND   valid_from_to.valid_from >= {{ model }}.{{ valid_from_columns[loop.index0] }}
  AND   COALESCE(valid_from_to.valid_to, '9999-01-01') <= COALESCE({{ model }}.{{ valid_to_columns[loop.index0] }}, '9999-12-31')
{% endfor %}
{% endmacro %}
