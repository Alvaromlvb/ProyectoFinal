{#-
    Tráfico mensual por punto. Base de los modelos de hitos y del ranking.

    El perfil da los vehículos de un día medio por día de la semana y hora. El volumen del
    mes se reconstruye multiplicando cada día de la semana por cuántas veces aparece en el
    mes (dim_tiempo.n_dias). imd = intensidad media diaria del mes.
-#}

with trafico as (

    select
        f.id_punto_medida_trafico,
        t.anno,
        t.mes,
        t.fecha_mes,
        t.num_dia_semana,
        t.tipo_dia,
        t.n_dias,
        f.num_vehiculos
    from {{ ref('fct_medida_trafico') }} as f
    inner join {{ ref('dim_tiempo') }} as t
        on f.id_tiempo = t.id_tiempo

),

por_dia_semana as (

    select
        id_punto_medida_trafico,
        anno,
        mes,
        fecha_mes,
        num_dia_semana,
        tipo_dia,
        n_dias,
        sum(num_vehiculos)   as vehiculos_dia
    from trafico
    group by all

),

final as (

    select
        id_punto_medida_trafico,
        anno,
        mes,
        fecha_mes,
        sum(vehiculos_dia * n_dias)                                         as vehiculos_mes,
        sum(n_dias)                                                         as dias_mes,
        sum(vehiculos_dia * n_dias) / sum(n_dias)                           as imd,
        sum(iff(tipo_dia = 'laborable', vehiculos_dia * n_dias, 0))
            / nullif(sum(iff(tipo_dia = 'laborable', n_dias, 0)), 0)        as imd_laborable,
        sum(iff(tipo_dia = 'fin_de_semana', vehiculos_dia * n_dias, 0))
            / nullif(sum(iff(tipo_dia = 'fin_de_semana', n_dias, 0)), 0)    as imd_fin_de_semana
    from por_dia_semana
    group by id_punto_medida_trafico, anno, mes, fecha_mes

)

select * from final
