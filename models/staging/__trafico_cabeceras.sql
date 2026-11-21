{#-
    Cabecera de cada fichero de tráfico (líneas 1 a 4), una fila por fichero = punto y mes.
    El año, el mes y el PM salen del nombre del fichero; los campos de la cabecera se
    conservan para detectar discrepancias y se anulan cuando vienen corruptos.
-#}

with source as (

    select * from {{ source('ayto_gr', 'raw_trafico_lineas') }}

),

lineas as (

    select
        fichero,
        num_linea,
        trim(replace(linea, '"', ''))   as linea,   -- los ficheros de 2020 vienen entrecomillados
        LOADED_AT
    from source

),

por_fichero as (

    select
        fichero,
        count(*)                                  as n_lineas,
        max(iff(num_linea = 1, linea, null))      as linea_pm,
        max(iff(num_linea = 2, linea, null))      as linea_direccion,
        max(iff(num_linea = 3, linea, null))      as linea_xy,
        max(iff(num_linea = 4, linea, null))      as linea_imd,
        max(LOADED_AT)                           as LOADED_AT
    from lineas
    group by fichero

),

marcado as (

    select
        *,
        n_lineas = 12                                         as es_fichero_completo,
        startswith(linea_direccion, 'StringJoin[')
            or startswith(linea_direccion, 'Floor[')          as es_direccion_corrupta,
        contains(linea_xy, 'StringJoin[')
            or contains(linea_xy, 'Floor[')                   as es_xy_corrupta
    from por_fichero

),

final as (

    select
        fichero,
        {{ trafico_fichero('fichero', 'pm') }}                as pm,
        {{ trafico_fichero('fichero', 'anio') }}              as anio,
        {{ trafico_fichero('fichero', 'mes') }}               as mes,
        date_from_parts(
            {{ trafico_fichero('fichero', 'anio') }},
            {{ trafico_fichero('fichero', 'mes') }},
            1
        )                                                     as fecha_mes,

        -- Línea 1: "PM: ,122" o "PM,122"
        iff(es_fichero_completo,
            try_to_number(trim(split_part(linea_pm, ',', 2))),
            null)                                             as pm_cabecera,

        -- Línea 2: dirección, sin el punto o guion bajo final
        iff(es_fichero_completo and not es_direccion_corrupta,
            nullif(regexp_replace(linea_direccion, '[ ._]+$', ''), ''),
            null)                                             as direccion_cabecera,

        -- Línea 3: "X: ,446369,Y: ,4113023"
        iff(es_fichero_completo and not es_xy_corrupta,
            try_to_decimal(trim(split_part(linea_xy, ',', 2)), 12, 2),
            null)                                             as utm_x_cabecera,
        iff(es_fichero_completo and not es_xy_corrupta,
            try_to_decimal(trim(split_part(linea_xy, ',', 4)), 12, 2),
            null)                                             as utm_y_cabecera,

        -- Línea 4: "IMD: ,3435" o "IMD:,3435"
        iff(es_fichero_completo,
            try_to_number(trim(split_part(linea_imd, ',', 2))),
            null)                                             as imd,

        n_lineas,
        es_fichero_completo,
        es_direccion_corrupta or es_xy_corrupta               as es_cabecera_corrupta,
        LOADED_AT
    from marcado

)

select * from final
