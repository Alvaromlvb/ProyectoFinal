{#-
    Casos 2 y 3 · Efecto de cada hito (zona 30, circunvalación, COVID, RD 970/2020)
    sobre el tráfico y el NO2.

    Grano: hito × estación × mes, para los meses dentro de ±ventana alrededor del hito.
    Cada mes se compara con el mismo mes del año anterior, lo que quita la estacionalidad:
      - tráfico de la ciudad: solo los puntos con datos en los dos meses (comparación pareada),
      - NO2 de la estación: solo es comparable si los dos meses superan la cobertura mínima.
    respuesta_no2_por_trafico = var_no2 / var_trafico: cuánto cambia el NO2 por cada
    punto que cambia el tráfico. Solo se calcula si el tráfico cambia al menos un 5 %.
    Comparar la estación de tráfico con las de fondo sirve de control.
-#}

{%- set ventana = var('ventana_hito_meses', 12) -%}
{%- set var_trafico_minima = 0.05 -%}

with trafico as (

    select * from {{ ref('int_trafico_punto_mensual') }}

),

no2 as (

    select * from {{ ref('int_no2_estacion_mensual') }}

),

estaciones as (

    select * from {{ ref('dim_estaciones_no2') }}

),

hitos as (

    select
        hito_id,
        nombre                                 as hito_nombre,
        tipo                                   as hito_tipo,
        fecha_inicio,
        fecha_fin,
        date_trunc('month', fecha_inicio)      as mes_inicio,
        date_trunc('month', fecha_fin)         as mes_fin
    from {{ ref('seed_hitos') }}

),

trafico_interanual as (

    select
        act.fecha_mes,
        count(*)                                      as n_puntos_trafico,
        sum(act.imd)                                  as imd_puntos,
        sum(ant.imd)                                  as imd_puntos_anio_anterior,
        sum(act.imd) / nullif(sum(ant.imd), 0) - 1    as var_trafico_pct
    from trafico as act
    inner join trafico as ant
        on  act.id_punto_medida_trafico = ant.id_punto_medida_trafico
        and ant.fecha_mes = add_months(act.fecha_mes, -12)
    group by act.fecha_mes

),

no2_interanual as (

    select
        act.id_estacion_no2,
        act.fecha_mes,
        act.no2_medio,
        ant.no2_medio                                     as no2_medio_anio_anterior,
        act.no2_medio / nullif(ant.no2_medio, 0) - 1      as var_no2_pct,
        act.es_mes_valido and coalesce(ant.es_mes_valido, false)
                                                          as es_no2_comparable
    from no2 as act
    left join no2 as ant
        on  act.id_estacion_no2 = ant.id_estacion_no2
        and ant.fecha_mes = add_months(act.fecha_mes, -12)

),

hitos_meses as (

    select
        h.*,
        n.id_estacion_no2,
        n.fecha_mes,
        datediff(month, h.mes_inicio, n.fecha_mes)   as meses_desde_hito
    from hitos as h
    inner join no2_interanual as n
        on datediff(month, h.mes_inicio, n.fecha_mes) between -{{ ventana }} and {{ ventana }}

),

final as (

    select
        hm.hito_id,
        hm.hito_nombre,
        hm.hito_tipo,
        hm.fecha_mes,
        year(hm.fecha_mes)                                   as anno,
        month(hm.fecha_mes)                                  as mes,
        hm.meses_desde_hito,
        case
            when hm.fecha_mes < hm.mes_inicio then 'antes'
            when hm.fecha_mes = hm.mes_inicio then 'mes_del_hito'
            when hm.mes_fin is not null and hm.fecha_mes <= hm.mes_fin then 'durante'
            else 'despues'
        end                                                  as fase,

        hm.id_estacion_no2,
        e.cod_estacion,
        e.nombre                                             as estacion,
        e.tipo_estacion,

        t.n_puntos_trafico,
        t.imd_puntos,
        t.imd_puntos_anio_anterior,
        round(t.var_trafico_pct, 4)                          as var_trafico_pct,

        round(n.no2_medio, 2)                                as no2_medio,
        round(n.no2_medio_anio_anterior, 2)                  as no2_medio_anio_anterior,
        round(iff(n.es_no2_comparable, n.var_no2_pct, null), 4)
                                                             as var_no2_pct,
        n.es_no2_comparable,

        round(iff(n.es_no2_comparable and abs(t.var_trafico_pct) >= {{ var_trafico_minima }},
                  n.var_no2_pct / t.var_trafico_pct,
                  null), 3)                                  as respuesta_no2_por_trafico
    from hitos_meses as hm
    inner join estaciones as e
        on hm.id_estacion_no2 = e.id_estacion_no2
    inner join no2_interanual as n
        on  hm.id_estacion_no2 = n.id_estacion_no2
        and hm.fecha_mes = n.fecha_mes
    left join trafico_interanual as t
        on hm.fecha_mes = t.fecha_mes

)

select * from final
