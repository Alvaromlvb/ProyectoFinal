{#-
    NO2 al grano del perfil de tráfico: estación × año × mes × día de la semana × hora local.

    1. Solo horas válidas.
    2. UTC → hora local de Madrid. MITECO da la hora en que termina la medida, así que
       se toma el inicio (ts_utc_fin - 1 h), se convierte y se suma 1: hora 1 = 00:00-01:00,
       igual que el tráfico.
    3. Media de los días de ese tipo en el mes, como hace el Ayuntamiento con el tráfico.
       n_horas_validas permite filtrar por cobertura (n_horas_validas / dim_tiempo.n_dias)
       y ponderar al agregar en gold.
-#}

{%- set anno_inicio = 2015 -%}
{%- set anno_fin = 2021 -%}

with no2 as (

    select
        cod_estacion,
        convert_timezone('UTC', 'Europe/Madrid', dateadd(hour, -1, ts_utc_fin))  as ts_inicio_local,
        no2_ugm3
    from {{ ref('__no2_horario') }}
    where es_valido

),

hora_local as (

    select
        cod_estacion,
        year(ts_inicio_local)              as anno,
        month(ts_inicio_local)             as mes,
        dayofweekiso(ts_inicio_local)      as num_dia_semana,
        hour(ts_inicio_local) + 1          as hora,
        no2_ugm3
    from no2
    where year(ts_inicio_local) between {{ anno_inicio }} and {{ anno_fin }}

),

agregado as (

    select
        cod_estacion,
        anno,
        mes,
        num_dia_semana,
        iff(num_dia_semana <= 5, 'laborable', 'fin_de_semana')   as tipo_dia,
        hora,
        avg(no2_ugm3)                                           as no2,
        count(*)                                                as n_horas_validas
    from hora_local
    group by cod_estacion, anno, mes, num_dia_semana, hora

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['cod_estacion', 'anno', 'mes', 'num_dia_semana', 'hora']) }}  as id_medida_no2,
        {{ dbt_utils.generate_surrogate_key(['cod_estacion']) }}                                           as id_estacion_no2,
        {{ dbt_utils.generate_surrogate_key(['anno', 'mes', 'num_dia_semana']) }}                          as id_tiempo,
        {{ dbt_utils.generate_surrogate_key(['tipo_dia', 'hora']) }}                                       as id_hora,
        round(no2, 2)                                                                                     as no2,
        n_horas_validas
    from agregado

)

select * from final
