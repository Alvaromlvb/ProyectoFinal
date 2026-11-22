{#-
    Perfil horario de tráfico: una fila por punto, mes, día de la semana y hora.
    Sale de las líneas 6 a 12 (lunes a domingo) de los ficheros completos:
    campo 0 = día, campos 1-24 = horas, campo 25 = total diario del fichero.
-#}

with source as (

    select * from {{ source('ayto_gr', 'raw_trafico_lineas') }}

),

ficheros_completos as (

    select fichero
    from source
    group by fichero
    having count(*) = 12

),

lineas_dia as (

    select
        s.fichero,
        split(trim(replace(s.linea, '"', '')), ',')   as campos   -- quita comillas de 2020
    from source as s
    inner join ficheros_completos as f
        on s.fichero = f.fichero
    where s.num_linea between 6 and 12

),

horas as (

    select
        d.fichero,
        lower(trim(d.campos[0]::varchar))                as dia_semana,
        h.index::int                                     as hora,
        try_to_number(trim(h.value::varchar))            as vehiculos_hora,
        try_to_number(trim(d.campos[25]::varchar))       as imd_dia_fichero
    from lineas_dia as d,
        lateral flatten(input => d.campos) as h
    where h.index between 1 and 24

),

final as (

    select
        fichero,
        {{ trafico_fichero('fichero', 'pm') }}           as pm,
        {{ trafico_fichero('fichero', 'anio') }}         as anio,
        {{ trafico_fichero('fichero', 'mes') }}          as mes,
        date_from_parts(
            {{ trafico_fichero('fichero', 'anio') }},
            {{ trafico_fichero('fichero', 'mes') }},
            1
        )                                                as fecha_mes,
        dia_semana,
        decode(dia_semana,
            'lun', 1, 'mar', 2, 'mie', 3, 'jue', 4,
            'vie', 5, 'sab', 6, 'dom', 7)                as num_dia_semana,
        hora,
        vehiculos_hora,
        imd_dia_fichero
    from horas

)

select * from final
