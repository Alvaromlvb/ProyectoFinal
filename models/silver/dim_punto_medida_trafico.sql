{#-
    Puntos de medida de tráfico: una fila por PM con su ubicación canónica en latitud/longitud.

    La ubicación sale de la cabecera más reciente que sea fiable:
      - fichero completo y cabecera no corrupta,
      - el PM de la cabecera coincide con el del nombre del fichero,
      - fuera de jun-oct 2016, cuando las cabeceras están cambiadas de punto.
    Las cabeceras traen UTM 30N. Hasta sep-2019 (salvo abr-2018) vienen en ED50 y se
    pasan a ETRS89 restando el desplazamiento medido en los datos (unos 112 m en X y
    206 m en Y); después se convierten a latitud/longitud con la fórmula de ubicacion_latlon. Las UTM no salen de este modelo.
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

ubicacion_utm as (

    select
        pm,
        mes_cabecera_referencia,
        direccion_cabecera                                                     as direccion,
        iff(es_origen_ed50, utm_x_cabecera - {{ ed50_dx }}, utm_x_cabecera)::float  as utm_x,
        iff(es_origen_ed50, utm_y_cabecera - {{ ed50_dy }}, utm_y_cabecera)::float  as utm_y
    from cabecera_referencia

),

{#-
    UTM huso 30N (ETRS89) → latitud/longitud. Fórmula inversa de Transverse Mercator
    (Snyder, USGS 1987) con el elipsoide GRS80. No se usa ST_TRANSFORM porque
    compilarlo cuesta segundos por cada vez que aparece en la consulta.
    Error frente a las coordenadas oficiales de las estaciones: menos de 1 m.
-#}
{%- set k0     = 0.9996 -%}
{%- set a      = 6378137.0 -%}
{%- set e2     = 0.006694380022900787 -%}     {#- excentricidad² -#}
{%- set ep2    = 0.006739496775478957 -%}     {#- segunda excentricidad² -#}
{%- set mu_den = 6367449.145908449 -%}        {#- a·(1 - e²/4 - 3e⁴/64 - 5e⁶/256) -#}
{%- set c2     = 0.0025188265967581876 -%}
{%- set c4     = 3.7009490719640127e-06 -%}
{%- set c6     = 7.447813877211132e-09 -%}
{%- set c8     = 1.7035993573185927e-11 -%}
{%- set lon0   = -3.0 -%}                     {#- meridiano central del huso 30 -#}

ubicacion_latlon as (

    select
        pm,
        mes_cabecera_referencia,
        direccion,

        -- latitud de pie de la perpendicular
        (utm_y / {{ k0 }}) / {{ mu_den }}                                   as mu,
        mu + {{ c2 }} * sin(2 * mu) + {{ c4 }} * sin(4 * mu)
           + {{ c6 }} * sin(6 * mu) + {{ c8 }} * sin(8 * mu)                as phi1,

        {{ ep2 }} * square(cos(phi1))                                       as c1,
        square(tan(phi1))                                                   as t1,
        {{ a }} / sqrt(1 - {{ e2 }} * square(sin(phi1)))                    as n1,
        {{ a }} * (1 - {{ e2 }}) / power(1 - {{ e2 }} * square(sin(phi1)), 1.5)  as r1,
        (utm_x - 500000) / (n1 * {{ k0 }})                                  as d,

        round(degrees(
            phi1 - (n1 * tan(phi1) / r1) * (
                  power(d, 2) / 2
                - (5 + 3 * t1 + 10 * c1 - 4 * square(c1) - 9 * {{ ep2 }}) * power(d, 4) / 24
                + (61 + 90 * t1 + 298 * c1 + 45 * square(t1) - 252 * {{ ep2 }} - 3 * square(c1)) * power(d, 6) / 720
            )
        ), 6)                                                               as latitud,

        round({{ lon0 }} + degrees(
            (   d
              - (1 + 2 * t1 + c1) * power(d, 3) / 6
              + (5 - 2 * c1 + 28 * t1 - 3 * square(c1) + 8 * {{ ep2 }} + 24 * square(t1)) * power(d, 5) / 120
            ) / cos(phi1)
        ), 6)                                                               as longitud

    from ubicacion_utm

),

estacion_cercana as (

    select
        u.pm,
        e.id_estacion_no2,
        st_distance(
            st_makepoint(u.longitud, u.latitud),   -- st_makepoint(longitud, latitud)
            st_makepoint(e.longitud, e.latitud)
        )                                                                as distancia_m   -- metros
    from ubicacion_latlon as u
    cross join estaciones as e
    qualify row_number() over (partition by u.pm order by distancia_m) = 1

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['a.pm']) }}    as id_punto_medida_trafico,
        a.pm,
        u.direccion,
        u.latitud,
        u.longitud,
        u.mes_cabecera_referencia,
        c.id_estacion_no2                                    as id_estacion_no2_cercana,
        round(c.distancia_m)                                 as distancia_estacion_m,
        a.primer_mes,
        a.ultimo_mes,
        a.n_meses_con_datos
    from actividad as a
    left join ubicacion_latlon as u
        on a.pm = u.pm
    left join estacion_cercana as c
        on a.pm = c.pm

)

select * from final
