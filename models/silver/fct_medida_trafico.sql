{#-
    Tráfico: vehículos por punto, año, mes, día de la semana y hora.
    Es el perfil del Ayuntamiento: la media de todos los días de ese tipo en el mes
    (festivos incluidos). Solo ficheros completos.

    Incremental: en cada ejecución solo se procesan los ficheros cargados en bronze
    después del último loaded_at de la tabla. Cada fichero es un punto y un mes, así que
    un fichero nuevo añade filas y uno recargado las sustituye (merge por id_medida_trafico).
-#}

{{ config(
    materialized='incremental',
    unique_key='id_medida_trafico',
    incremental_strategy='merge',
    on_schema_change='append_new_columns'
) }}

with trafico as (

    select
        pm,
        anno,
        mes,
        {{ num_dia_semana('dia_semana') }}   as num_dia_semana,
        hora,
        vehiculos_hora,
        loaded_at
    from {{ ref('__trafico') }}
    where es_fichero_completo
    {% if is_incremental() %}
      and loaded_at > (select max(loaded_at) from {{ this }})
    {% endif %}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['pm', 'anno', 'mes', 'num_dia_semana', 'hora']) }}  as id_medida_trafico,
        {{ dbt_utils.generate_surrogate_key(['pm']) }}                                         as id_punto_medida_trafico,
        {{ dbt_utils.generate_surrogate_key(['anno', 'mes', 'num_dia_semana', 'hora']) }}      as id_tiempo,
        vehiculos_hora                                                                         as num_vehiculos,
        loaded_at
    from trafico

)

select * from final
