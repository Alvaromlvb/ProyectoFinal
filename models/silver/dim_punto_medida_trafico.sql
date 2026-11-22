{#-
    Puntos de medida de tráfico: una fila por PM con su ubicación canónica.

    La ubicación sale de la cabecera más reciente que sea fiable:
      - fichero completo y cabecera no corrupta,
      - el PM de la cabecera coincide con el del nombre del fichero,
      - fuera de jun-oct 2016, cuando las cabeceras están cambiadas de punto.
    Hasta sep-2019 (salvo abr-2018) las coordenadas vienen en ED50 y se pasan a
    ETRS89 restando el desplazamiento medido en los datos (unos 112 m en X y 206 m en Y).
-#}

{%- set meses_cabecera_desplazada = ['2016-06-01', '2016-07-01', '2016-08-01', '2016-09-01', '2016-10-01'] -%}
{%- set inicio_etrs89 = '2019-10-01' -%}
{%- set meses_etrs89_previos = ['2018-04-01'] -%}
{%- set ed50_dx = 112 -%}
{%- set ed50_dy = 206 -%}

with cabeceras as (

    select * from {{ ref('__trafico_cabeceras') }}

),

estaciones as (

    select * from {{ ref('dim_estaciones_no2') }}

),

actividad as (

    select
        pm,
        min(fecha_mes)                      as primer_mes,
        max(fecha_mes)                      as ultimo_mes,
        count_if(es_fichero_completo)       as n_meses_con_datos
    from cabeceras
    group by pm

),

cabecera_referencia as (

    select
        pm,
        fecha_mes                                                   as mes_cabecera_referencia,
        direccion_cabecera,
        utm_x_cabecera,
        utm_y_cabecera,
        fecha_mes < '{{ inicio_etrs89 }}'::date
            and fecha_mes not in ('{{ meses_etrs89_previos | join("'::date, '") }}'::date)
                                                                    as es_origen_ed50
    from cabeceras
    where es_fichero_completo
      and not es_cabecera_corrupta
      and pm_cabecera = pm
      and utm_x_cabecera is not null
      and fecha_mes not in ('{{ meses_cabecera_desplazada | join("'::date, '") }}'::date)
    qualify row_number() over (partition by pm order by fecha_mes desc) = 1

),

ubicacion as (

    select
        pm,
        mes_cabecera_referencia,
        direccion_cabecera                                              as direccion,
        es_origen_ed50,
        iff(es_origen_ed50, utm_x_cabecera - {{ ed50_dx }}, utm_x_cabecera)  as utm_x_etrs89,
        iff(es_origen_ed50, utm_y_cabecera - {{ ed50_dy }}, utm_y_cabecera)  as utm_y_etrs89,
        st_transform(
            st_makegeompoint(
                iff(es_origen_ed50, utm_x_cabecera - {{ ed50_dx }}, utm_x_cabecera),
                iff(es_origen_ed50, utm_y_cabecera - {{ ed50_dy }}, utm_y_cabecera)
            ),
            25830, 4326
        )                                                               as geom_wgs84
    from cabecera_referencia

),

estacion_cercana as (

    select
        u.pm,
        e.id_estacion_no2,
        sqrt(
            square(u.utm_x_etrs89 - e.utm_x_etrs89)
            + square(u.utm_y_etrs89 - e.utm_y_etrs89)
        )                                                               as distancia_m
    from ubicacion as u
    cross join estaciones as e
    qualify row_number() over (partition by u.pm order by distancia_m) = 1

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['a.pm']) }}    as id_punto_medida_trafico,
        a.pm,
        u.direccion,
        u.utm_x_etrs89,
        u.utm_y_etrs89,
        round(st_y(u.geom_wgs84), 6)                         as latitud,
        round(st_x(u.geom_wgs84), 6)                         as longitud,
        u.mes_cabecera_referencia,
        u.es_origen_ed50,
        c.id_estacion_no2                                    as id_estacion_no2_cercana,
        round(c.distancia_m)                                 as distancia_estacion_m,
        a.primer_mes,
        a.ultimo_mes,
        a.n_meses_con_datos
    from actividad as a
    left join ubicacion as u
        on a.pm = u.pm
    left join estacion_cercana as c
        on a.pm = c.pm

)

select * from final
