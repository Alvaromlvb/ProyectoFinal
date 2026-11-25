{#-
    Extrae el año, el mes o el código de punto de la ruta de un fichero de tráfico
    del Ayuntamiento, con el formato <anno>_<mes>/<pm>.csv[.gz].
    Uso: {{ trafico_fichero('fichero', 'anno') }}  ·  partes: 'anno', 'mes', 'pm'
-#}
{% macro trafico_fichero(columna, parte) -%}
    {%- set grupos = {'anno': 1, 'mes': 2, 'pm': 3} -%}
    {%- if parte not in grupos -%}
        {{ exceptions.raise_compiler_error("trafico_fichero: parte debe ser 'anno', 'mes' o 'pm', no '" ~ parte ~ "'") }}
    {%- endif -%}
    regexp_substr({{ columna }}, '([0-9]{4})_([0-9]{2})/([0-9]+)[.]csv', 1, 1, 'e', {{ grupos[parte] }})::int
{%- endmacro %}
