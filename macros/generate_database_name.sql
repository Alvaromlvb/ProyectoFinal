{% macro generate_database_name(custom_database_name=none, node=none) -%}
    {%- set entorno = env_var('DBT_ENTORNO', 'DEV') | upper -%}
    {%- if custom_database_name is none -%}
        {{ target.database }}
    {%- else -%}
        {{ entorno }}_{{ custom_database_name | trim | upper }}
    {%- endif -%}
{%- endmacro %}