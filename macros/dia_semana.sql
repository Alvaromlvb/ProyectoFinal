{#-
    Conversión entre el día de la semana en texto (lun..dom, como viene en los ficheros de
    tráfico) y su número ISO (1 = lunes … 7 = domingo).
    Uso: {{ num_dia_semana('dia_semana') }}  ·  {{ nombre_dia_semana('num_dia_semana') }}
-#}
{% macro num_dia_semana(columna) -%}
    decode({{ columna }},
        'lun', 1, 'mar', 2, 'mie', 3, 'jue', 4,
        'vie', 5, 'sab', 6, 'dom', 7)
{%- endmacro %}

{% macro nombre_dia_semana(columna) -%}
    decode({{ columna }},
        1, 'lun', 2, 'mar', 3, 'mie', 4, 'jue',
        5, 'vie', 6, 'sab', 7, 'dom')
{%- endmacro %}
