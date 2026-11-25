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
        nombre,
        nombre_municipio,
        tipo_estacion,
        tipo_area,
        direccion,
        latitud,
        longitud,
        altitud_m                                                 as altitud,
        fecha_alta,
        punto_muestreo_no2
    from estaciones

)

select * from final
