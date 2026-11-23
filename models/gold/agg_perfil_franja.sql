{#-
    Caso 5 · Reparto del tráfico de la ciudad por franjas horarias.

    Grano: mes × tipo de día × franja. pct_trafico_dia es la parte del tráfico diario
    que cae en la franja (todas las franjas de un mes y tipo de día suman 1).
    En fin de semana la "noche" son dos tramos (1-3 h y 20-24 h) y se suman.
-#}

with trafico as (

    select
        f.id_punto_medida_trafico,
        t.anno,
        t.mes,
        t.fecha_mes,
        t.num_dia_semana,
        t.n_dias,
        h.tipo_dia,
        h.franja_horaria,
        h.orden_franja,
        f.num_vehiculos
    from {{ ref('fct_medida_trafico') }} as f
    inner join {{ ref('dim_tiempo') }} as t
        on f.id_tiempo = t.id_tiempo
    inner join {{ ref('dim_hora') }} as h
        on f.id_hora = h.id_hora

),

por_punto_dia as (

    select
        id_punto_medida_trafico,
        anno,
        mes,
        fecha_mes,
        num_dia_semana,
        n_dias,
        tipo_dia,
        franja_horaria,
        min(orden_franja)    as orden_franja,
        sum(num_vehiculos)   as vehiculos_franja
    from trafico
    group by all

),

por_franja as (

    select
        anno,
        mes,
        fecha_mes,
        tipo_dia,
        franja_horaria,
        min(orden_franja)                              as orden_franja,
        count(distinct id_punto_medida_trafico)        as n_puntos_trafico,
        sum(vehiculos_franja * n_dias)                 as vehiculos_franja_ponderado,
        sum(n_dias)                                    as dias_punto
    from por_punto_dia
    group by anno, mes, fecha_mes, tipo_dia, franja_horaria

),

final as (

    select
        anno,
        mes,
        fecha_mes,
        tipo_dia,
        franja_horaria,
        orden_franja,
        n_puntos_trafico,
        round(vehiculos_franja_ponderado / dias_punto, 1)            as vehiculos_dia_medio_punto,
        round(
            vehiculos_franja_ponderado
            / sum(vehiculos_franja_ponderado) over (partition by fecha_mes, tipo_dia),
            4
        )                                                            as pct_trafico_dia
    from por_franja

)

select * from final
