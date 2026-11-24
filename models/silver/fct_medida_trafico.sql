{#-
    Tráfico: vehículos por punto, año, mes, día de la semana y hora.
    Es el perfil del Ayuntamiento: la media de todos los días de ese tipo en el mes
    (festivos incluidos). Solo ficheros completos.
-#}

with perfiles as (

    select
        *,
        iff(num_dia_semana <= 5, 'laborable', 'fin_de_semana') as tipo_dia
    from {{ ref('__trafico_perfiles') }}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['pm', 'anio', 'mes', 'num_dia_semana', 'hora']) }}  as id_medida_trafico,
        {{ dbt_utils.generate_surrogate_key(['pm']) }}                                         as id_punto_medida_trafico,
        {{ dbt_utils.generate_surrogate_key(['anio', 'mes', 'num_dia_semana']) }}              as id_tiempo,
        {{ dbt_utils.generate_surrogate_key(['tipo_dia', 'hora']) }}                           as id_hora,
        vehiculos_hora                                                                         as num_vehiculos
    from perfiles

)

select * from final
