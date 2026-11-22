{#-
    Estaciones de calidad del aire de Granada que miden NO2 (seed_estaciones).
-#}

with estaciones as (

    select * from {{ ref('seed_estaciones') }}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['cod_estacion']) }}  as id_estacion_no2,
        cod_estacion,
        cod_estacion_eu,
        nombre,
        nombre_municipio,
        tipo_estacion,
        tipo_area,
        direccion,
        latitud,
        longitud,
        altitud_m,
        utm_x_etrs89,
        utm_y_etrs89,
        fecha_alta,
        punto_muestreo_no2
    from estaciones

)

select * from final
