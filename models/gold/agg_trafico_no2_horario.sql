{#-
    Caso 4 · Tráfico del entorno y NO2 de cada estación, hora a hora.

    Grano: estación × mes × día de la semana × hora (el de las dos tablas de hechos).
    Entorno = puntos de tráfico a menos de radio_entorno_estacion_m de la estación
    (1000 m por defecto: unos 22 puntos en Granada Norte, 58 en Palacio de Congresos y
    ninguno en Ciudad Deportiva, que es de fondo).
    vehiculos_medio_punto es la media por punto, para que no dependa de cuántos puntos
    hay activos ese mes.
-#}

{%- set radio_m = var('radio_entorno_estacion_m', 1000) -%}
{%- set cobertura_minima = var('cobertura_minima_mes', 0.75) -%}

with estaciones as (

    select * from {{ ref('dim_estaciones_no2') }}

),

puntos as (

    select * from {{ ref('dim_punto_medida_trafico') }}

),

entorno as (

    select
        e.id_estacion_no2,
        p.id_punto_medida_trafico
    from estaciones as e
    inner join puntos as p
        on st_distance(
               st_makepoint(p.longitud, p.latitud),
               st_makepoint(e.longitud, e.latitud)
           ) <= {{ radio_m }}

),

trafico_entorno as (

    select
        en.id_estacion_no2,
        f.id_tiempo,
        f.id_hora,
        count(*)               as n_puntos_trafico,
        avg(f.num_vehiculos)   as vehiculos_medio_punto,
        sum(f.num_vehiculos)   as vehiculos_total
    from {{ ref('fct_medida_trafico') }} as f
    inner join entorno as en
        on f.id_punto_medida_trafico = en.id_punto_medida_trafico
    group by en.id_estacion_no2, f.id_tiempo, f.id_hora

),

final as (

    select
        n.id_estacion_no2,
        e.cod_estacion,
        e.nombre                                          as estacion,
        e.tipo_estacion,
        t.anno,
        t.mes,
        t.fecha_mes,
        t.dia_semana,
        t.num_dia_semana,
        h.tipo_dia,
        h.hora,
        h.franja_horaria,
        round(n.no2, 2)                                   as no2,
        n.n_horas_validas,
        least(n.n_horas_validas / t.n_dias, 1) >= {{ cobertura_minima }}
                                                          as es_no2_fiable,
        coalesce(tr.n_puntos_trafico, 0)                  as n_puntos_trafico,
        round(tr.vehiculos_medio_punto, 1)                as vehiculos_medio_punto,
        tr.vehiculos_total
    from {{ ref('fct_medida_no2') }} as n
    inner join estaciones as e
        on n.id_estacion_no2 = e.id_estacion_no2
    inner join {{ ref('dim_tiempo') }} as t
        on n.id_tiempo = t.id_tiempo
    inner join {{ ref('dim_hora') }} as h
        on n.id_hora = h.id_hora
    left join trafico_entorno as tr
        on  n.id_estacion_no2 = tr.id_estacion_no2
        and n.id_tiempo = tr.id_tiempo
        and n.id_hora = tr.id_hora

)

select * from final
