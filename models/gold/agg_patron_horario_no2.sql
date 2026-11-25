{#-
    Patrón horario de NO2 por estación: media de un día medio por estación, año, mes,
    día de la semana y hora local, con la ubicación de la estación.
    Mismo grano que agg_patron_horario_trafico.

    Solo hay fila si la combinación tiene al menos una hora válida. es_dato_fiable marca
    las que cubren al menos el 75 % de los días de ese tipo en el mes.
-#}

{%- set cobertura_minima = var('cobertura_minima_mes', 0.75) -%}

with no2 as (

    select * from {{ ref('fct_medida_no2') }}

),

estaciones as (

    select * from {{ ref('dim_estaciones_no2') }}

),

tiempo as (

    select * from {{ ref('dim_tiempo') }}

),

final as (

    select
        f.id_estacion_no2,
        e.nombre                                                    as estacion,
        e.tipo_estacion,
        e.latitud,
        e.longitud,
        t.anno,
        t.mes,
        t.dia_semana,
        {{ num_dia_semana('t.dia_semana') }}                        as num_dia_semana,
        t.hora,
        f.no2,
        f.n_horas_validas,
        least(f.n_horas_validas / t.n_dias, 1) >= {{ cobertura_minima }}
                                                                    as es_dato_fiable
    from no2 as f
    inner join estaciones as e
        on f.id_estacion_no2 = e.id_estacion_no2
    inner join tiempo as t
        on f.id_tiempo = t.id_tiempo

)

select * from final
