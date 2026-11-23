{#-
    NO2 mensual por estación, con cobertura. Hay una fila por estación y mes aunque no
    haya ningún dato (cobertura 0), para que los huecos se vean.

    no2_medio = media de todas las horas válidas del mes (media de los perfiles
    ponderada por n_horas_validas).
-#}

{%- set cobertura_minima = var('cobertura_minima_mes', 0.75) -%}

with no2 as (

    select
        f.id_estacion_no2,
        t.anno,
        t.mes,
        f.no2,
        f.n_horas_validas
    from {{ ref('fct_medida_no2') }} as f
    inner join {{ ref('dim_tiempo') }} as t
        on f.id_tiempo = t.id_tiempo

),

meses as (

    select
        anno,
        mes,
        fecha_mes,
        sum(n_dias) * 24   as horas_posibles
    from {{ ref('dim_tiempo') }}
    group by anno, mes, fecha_mes

),

estaciones_meses as (

    select
        e.id_estacion_no2,
        m.anno,
        m.mes,
        m.fecha_mes,
        m.horas_posibles
    from {{ ref('dim_estaciones_no2') }} as e
    cross join meses as m

),

agregado as (

    select
        id_estacion_no2,
        anno,
        mes,
        sum(no2 * n_horas_validas) / sum(n_horas_validas)   as no2_medio,
        sum(n_horas_validas)                                as horas_validas
    from no2
    group by id_estacion_no2, anno, mes

),

final as (

    select
        em.id_estacion_no2,
        em.anno,
        em.mes,
        em.fecha_mes,
        a.no2_medio,
        coalesce(a.horas_validas, 0)                                   as horas_validas,
        em.horas_posibles,
        -- el cambio de hora de octubre añade una hora: se limita a 1
        least(coalesce(a.horas_validas, 0) / em.horas_posibles, 1)     as cobertura,
        least(coalesce(a.horas_validas, 0) / em.horas_posibles, 1)
            >= {{ cobertura_minima }}                                  as es_mes_valido
    from estaciones_meses as em
    left join agregado as a
        on  em.id_estacion_no2 = a.id_estacion_no2
        and em.anno = a.anno
        and em.mes = a.mes

)

select * from final
