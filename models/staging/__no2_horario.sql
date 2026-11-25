{#-
    NO2 horario de las tres estaciones de Granada, una fila por estación, día y hora UTC.
    Las columnas H01..H24 pasan a filas; las horas sin dato se conservan con valor nulo.
-#}
{%- set estaciones = ['18087007', '18087010', '18021001'] -%}
{%- set columnas_hora -%}
    {%- for h in range(1, 25) -%}h{{ '%02d' | format(h) }}{{ ', ' if not loop.last }}{%- endfor -%}
{%- endset -%}

with source as (

    select * from {{ source('miteco', 'raw_no2_horario') }}

),

granada as (

    select
        split_part(trim(punto_muestreo), '_', 1)          as cod_estacion,
        trim(punto_muestreo)                              as punto_muestreo,
        date_from_parts(anno::int, mes::int, dia::int)    as fecha_utc,
        {{ columnas_hora }},
        fichero,
        loaded_at
    from source
    where split_part(trim(punto_muestreo), '_', 1) in ('{{ estaciones | join("', '") }}')
      and trim(magnitud) = '8'

),

horas as (

    select
        cod_estacion,
        punto_muestreo,
        fecha_utc,
        columna_hora,
        valor,
        fichero,
        loaded_at
    from granada
        unpivot include nulls (valor for columna_hora in ({{ columnas_hora }}))

),

final as (

    select
        cod_estacion,
        punto_muestreo,
        fecha_utc,
        right(columna_hora, 2)::int             as hora_utc,
        try_to_decimal(trim(valor), 10, 2)      as no2_ugm3,
        fichero,
        loaded_at
    from horas

)

select * from final
