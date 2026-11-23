{#-
    Caso 4 (resumen) · Relación entre el tráfico del entorno y el NO2 por estación,
    año y tipo de día.

    correlacion: Pearson entre vehiculos_medio_punto y no2 sobre todas las combinaciones
    mes × día × hora del año con NO2 fiable y tráfico en el entorno.
    pendiente_no2_por_100_vehiculos: cuántos µg/m³ sube el NO2 por cada 100 vehículos/hora
    más por punto (regresión lineal simple).
    Ojo: parte de la correlación viene del ciclo diario de la atmósfera (la mezcla vertical
    también cambia con la hora), no solo del tráfico.
-#}

with horario as (

    select * from {{ ref('agg_trafico_no2_horario') }}
    where es_no2_fiable
      and vehiculos_medio_punto is not null

),

final as (

    select
        id_estacion_no2,
        cod_estacion,
        estacion,
        tipo_estacion,
        anno,
        tipo_dia,
        count(*)                                                   as n_observaciones,
        round(avg(n_puntos_trafico), 1)                            as n_puntos_trafico_medio,
        round(corr(no2, vehiculos_medio_punto), 3)                 as correlacion,
        round(regr_slope(no2, vehiculos_medio_punto) * 100, 3)     as pendiente_no2_por_100_vehiculos,
        round(regr_intercept(no2, vehiculos_medio_punto), 2)       as no2_sin_trafico_estimado,
        round(regr_r2(no2, vehiculos_medio_punto), 3)              as r2
    from horario
    group by id_estacion_no2, cod_estacion, estacion, tipo_estacion, anno, tipo_dia

)

select * from final
