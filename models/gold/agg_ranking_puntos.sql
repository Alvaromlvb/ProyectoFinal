{#-
    Caso 6 · Ranking anual de puntos de tráfico, con ubicación para pintarlo en un mapa.

    Grano: punto × año.
    imd_anual: intensidad media diaria con los meses que tienen datos.
    ranking_imd: posición en el año, solo para puntos con al menos min_meses_ranking meses.
    var_interanual_pct: compara solo los meses con datos en los dos años (pareado), para
    que un mes que falta no parezca una subida o una bajada.
-#}

{%- set min_meses = var('min_meses_ranking', 9) -%}

with mensual as (

    select * from {{ ref('int_trafico_punto_mensual') }}

),

puntos as (

    select * from {{ ref('dim_punto_medida_trafico') }}

),

anual as (

    select
        id_punto_medida_trafico,
        anno,
        count(*)                                  as n_meses_con_datos,
        sum(vehiculos_mes) / sum(dias_mes)        as imd_anual,
        avg(imd_laborable)                        as imd_laborable,
        avg(imd_fin_de_semana)                    as imd_fin_de_semana
    from mensual
    group by id_punto_medida_trafico, anno

),

interanual as (

    select
        act.id_punto_medida_trafico,
        act.anno,
        count(*)                                                    as n_meses_comparados,
        sum(act.vehiculos_mes) / nullif(sum(ant.vehiculos_mes), 0) - 1
                                                                    as var_interanual_pct
    from mensual as act
    inner join mensual as ant
        on  act.id_punto_medida_trafico = ant.id_punto_medida_trafico
        and ant.fecha_mes = add_months(act.fecha_mes, -12)
    group by act.id_punto_medida_trafico, act.anno

),

final as (

    select
        a.id_punto_medida_trafico,
        p.pm,
        p.direccion,
        p.latitud,
        p.longitud,
        p.id_estacion_no2_cercana,
        p.distancia_estacion_m,
        a.anno,
        a.n_meses_con_datos,
        round(a.imd_anual)                                   as imd_anual,
        round(a.imd_laborable)                               as imd_laborable,
        round(a.imd_fin_de_semana)                           as imd_fin_de_semana,
        iff(a.n_meses_con_datos >= {{ min_meses }},
            rank() over (
                partition by a.anno, a.n_meses_con_datos >= {{ min_meses }}
                order by a.imd_anual desc
            ),
            null)                                            as ranking_imd,
        i.n_meses_comparados,
        round(i.var_interanual_pct, 4)                       as var_interanual_pct
    from anual as a
    inner join puntos as p
        on a.id_punto_medida_trafico = p.id_punto_medida_trafico
    left join interanual as i
        on  a.id_punto_medida_trafico = i.id_punto_medida_trafico
        and a.anno = i.anno

)

select * from final
