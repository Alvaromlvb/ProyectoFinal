{#-
    Tráfico del Ayuntamiento: una fila por fichero (punto y mes), día de la semana y hora.

    De cada fichero salen:
      - la cabecera (líneas 2 y 3: dirección y coordenadas), repetida en todas sus filas,
      - el perfil horario (líneas 6 a 12, de lunes a domingo; campos 1-24 = horas).
    El año, el mes y el PM salen del nombre del fichero. Los ficheros incompletos
    (2016_10/45) se conservan con una sola fila y dia_semana, hora y vehiculos_hora nulos.
    Las coordenadas se dejan como vienen (ED50 o ETRS89 según el periodo); se corrigen en silver.
    Si un fichero se ha cargado más de una vez en bronze, solo se usa la última carga.
-#}

with source as (

    select * from {{ source('ayto_gr', 'raw_trafico_lineas') }}
    qualify loaded_at = max(loaded_at) over (partition by fichero)

),

lineas as (

    select
        fichero,
        num_linea,
        trim(replace(linea, '"', ''))   as linea,   -- los ficheros de 2020 vienen entrecomillados
        loaded_at
    from source

),

cabeceras as (

    select
        fichero,
        count(*)                                  as n_lineas,
        max(iff(num_linea = 2, linea, null))      as linea_direccion,
        max(iff(num_linea = 3, linea, null))      as linea_xy,
        max(loaded_at)                            as loaded_at
    from lineas
    group by fichero

),

cabeceras_marcadas as (

    select
        *,
        n_lineas = 12                                         as es_fichero_completo,
        startswith(linea_direccion, 'StringJoin[')
            or startswith(linea_direccion, 'Floor[')          as es_direccion_corrupta,
        contains(linea_xy, 'StringJoin[')
            or contains(linea_xy, 'Floor[')                   as es_xy_corrupta
    from cabeceras

),

dias as (

    select
        fichero,
        split(linea, ',')   as campos
    from lineas
    where num_linea between 6 and 12

),

perfiles as (

    select
        d.fichero,
        lower(trim(d.campos[0]::varchar))        as dia_semana,
        h.index::int                             as hora,
        try_to_number(trim(h.value::varchar))    as vehiculos_hora
    from dias as d,
        lateral flatten(input => d.campos) as h
    where h.index between 1 and 24

),

final as (

    select
        c.fichero,
        {{ trafico_fichero('c.fichero', 'pm') }}              as pm,
        {{ trafico_fichero('c.fichero', 'anno') }}            as anno,
        {{ trafico_fichero('c.fichero', 'mes') }}             as mes,

        -- Línea 2: dirección, sin el punto o guion bajo final
        iff(c.es_fichero_completo and not c.es_direccion_corrupta,
            nullif(regexp_replace(c.linea_direccion, '[ ._]+$', ''), ''),
            null)                                             as direccion,

        -- Línea 3: "X: ,446369,Y: ,4113023" o "X: ,446369,Y:,4113023"
        iff(c.es_fichero_completo and not c.es_xy_corrupta,
            try_to_decimal(trim(split_part(c.linea_xy, ',', 2)), 12, 2),
            null)                                             as utm_x,
        iff(c.es_fichero_completo and not c.es_xy_corrupta,
            try_to_decimal(trim(split_part(c.linea_xy, ',', 4)), 12, 2),
            null)                                             as utm_y,

        c.n_lineas,
        c.es_fichero_completo,
        c.es_direccion_corrupta or c.es_xy_corrupta           as es_cabecera_corrupta,
        p.dia_semana,
        p.hora,
        p.vehiculos_hora,
        c.loaded_at
    from cabeceras_marcadas as c
    left join perfiles as p
        on  c.fichero = p.fichero
        and c.es_fichero_completo

)

select * from final
