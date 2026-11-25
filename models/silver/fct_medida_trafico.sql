{#-
    Tráfico: vehículos por punto, año, mes, día de la semana y hora.
    Es el perfil del Ayuntamiento: la media de todos los días de ese tipo en el mes
    (festivos incluidos). Solo ficheros completos.
-#}

with trafico as (

    select
        pm,
        anno,
        mes,
        {{ num_dia_semana('dia_semana') }}   as num_dia_semana,
        hora,
        vehiculos_hora
    from {{ ref('__trafico') }}
    where es_fichero_completo

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['pm', 'anno', 'mes', 'num_dia_semana', 'hora']) }}  as id_medida_trafico,
        {{ dbt_utils.generate_surrogate_key(['pm']) }}                                         as id_punto_medida_trafico,
        {{ dbt_utils.generate_surrogate_key(['anno', 'mes', 'num_dia_semana', 'hora']) }}      as id_tiempo,
        vehiculos_hora                                                                         as num_vehiculos
    from trafico

)

select * from final
