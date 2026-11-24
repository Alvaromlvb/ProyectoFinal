{#-
    Patrón horario de tráfico por calle: vehículos de un día medio por punto, año, mes,
    día de la semana y hora, con la ubicación del punto y la franja horaria.
    Mismo grano que fct_medida_trafico, con las dimensiones ya resueltas.
-#}

with trafico as (

    select * from {{ ref('fct_medida_trafico') }}

),

puntos as (

    select * from {{ ref('dim_punto_medida_trafico') }}

),

tiempo as (

    select * from {{ ref('dim_tiempo') }}

),

horas as (

    select * from {{ ref('dim_hora') }}

),

final as (

    select
        f.id_punto_medida_trafico,
        p.latitud,
        p.longitud,
        t.anno,
        t.mes,
        t.dia_semana,
        t.num_dia_semana,
        h.hora,
        h.franja_horaria,
        f.num_vehiculos
    from trafico as f
    inner join puntos as p
        on f.id_punto_medida_trafico = p.id_punto_medida_trafico
    inner join tiempo as t
        on f.id_tiempo = t.id_tiempo
    inner join horas as h
        on f.id_hora = h.id_hora

)

select * from final
