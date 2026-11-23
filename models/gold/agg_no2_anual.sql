{#-
    Caso 7 · Media anual de NO2 por estación frente a los valores límite.

    - Límite anual vigente (Directiva 2008/50/CE, RD 102/2011): 40 µg/m³.
    - Límite anual desde 2030 (Directiva (UE) 2024/2881): 20 µg/m³.
    La directiva exige un 90 % de datos válidos para que la media anual sea representativa
    (es_anio_valido). El límite horario (200 µg/m³) no se puede evaluar aquí: el NO2 de
    silver son medias de varios días por hora y aplanan los picos.
-#}

{%- set limite_vigente = 40 -%}
{%- set limite_2030 = 20 -%}
{%- set cobertura_minima = var('cobertura_minima_anio', 0.90) -%}

with mensual as (

    select * from {{ ref('int_no2_estacion_mensual') }}

),

estaciones as (

    select * from {{ ref('dim_estaciones_no2') }}

),

anual as (

    select
        id_estacion_no2,
        anno,
        sum(no2_medio * horas_validas) / nullif(sum(horas_validas), 0)   as no2_medio_anual,
        sum(horas_validas)                                               as horas_validas,
        sum(horas_posibles)                                              as horas_posibles,
        count_if(es_mes_valido)                                          as n_meses_validos
    from mensual
    group by id_estacion_no2, anno

),

final as (

    select
        a.id_estacion_no2,
        e.cod_estacion,
        e.nombre                                                   as estacion,
        e.tipo_estacion,
        e.tipo_area,
        a.anno,
        round(a.no2_medio_anual, 1)                                as no2_medio_anual,
        a.horas_validas,
        a.horas_posibles,
        round(least(a.horas_validas / a.horas_posibles, 1), 4)     as cobertura,
        least(a.horas_validas / a.horas_posibles, 1) >= {{ cobertura_minima }}
                                                                   as es_anio_valido,
        a.n_meses_validos,
        {{ limite_vigente }}                                       as limite_anual_vigente,
        a.no2_medio_anual > {{ limite_vigente }}                   as supera_limite_vigente,
        {{ limite_2030 }}                                          as limite_anual_2030,
        a.no2_medio_anual > {{ limite_2030 }}                      as supera_limite_2030
    from anual as a
    inner join estaciones as e
        on a.id_estacion_no2 = e.id_estacion_no2

)

select * from final
