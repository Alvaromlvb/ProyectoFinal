{#-
    NO2 al grano del perfil de tráfico: estación × año × mes × día de la semana × hora local.

    1. UTC → hora local de Madrid. MITECO da la hora en que termina la medida (hora_utc 1 =
       00:00-01:00 UTC), así que se toma el inicio (fecha_utc + hora_utc - 1), se convierte
       y se suma 1: hora 1 = 00:00-01:00 local, igual que el tráfico.
    2. Solo horas con dato válido (no2_ugm3 no nulo).
    3. Media de los días de ese tipo en el mes, como hace el Ayuntamiento con el tráfico.
       n_horas_validas permite filtrar por cobertura (n_horas_validas / dim_tiempo.n_dias)
       y ponderar al agregar.

    Incremental: un dato nuevo cambia la media de su mes, así que no basta con añadir filas.
      a. Se buscan los meses (en hora local) con datos cargados después del último
         loaded_at de la tabla.
      b. Se generan todas las combinaciones estación × día × hora de esos meses y se
         recalculan. Las que se han quedado sin ninguna hora válida salen con
         n_horas_validas = 0.
      c. merge por id_medida_no2: actualiza las existentes y añade las nuevas.
      d. El post_hook borra las filas con n_horas_validas = 0. Así una combinación que
         pierde todos sus datos desaparece de la tabla.
-#}

{{ config(
    materialized='incremental',
    unique_key='id_medida_no2',
    incremental_strategy='merge',
    on_schema_change='append_new_columns',
    post_hook="delete from {{ this }} where n_horas_validas = 0"
) }}

{%- set anno_inicio = 2015 -%}
{%- set anno_fin = 2021 -%}

with no2 as (

    select
        cod_estacion,
        convert_timezone(
            'UTC', 'Europe/Madrid',
            dateadd(hour, hora_utc - 1, fecha_utc::timestamp_ntz)
        )                                       as ts_inicio_local,
        no2_ugm3,
        loaded_at
    from {{ ref('__no2_horario') }}

),

hora_local as (

    select
        cod_estacion,
        year(ts_inicio_local)              as anno,
        month(ts_inicio_local)             as mes,
        dayofweekiso(ts_inicio_local)      as num_dia_semana,
        hour(ts_inicio_local) + 1          as hora,
        no2_ugm3,
        loaded_at
    from no2
    where year(ts_inicio_local) between {{ anno_inicio }} and {{ anno_fin }}

),

{% if is_incremental() %}
meses_afectados as (

    -- incluye las horas sin dato: una hora que deja de ser válida también cambia el mes
    select distinct
        anno,
        mes
    from hora_local
    where loaded_at > (select max(loaded_at) from {{ this }})

),
{% endif %}

agregado as (

    select
        cod_estacion,
        anno,
        mes,
        num_dia_semana,
        hora,
        avg(no2_ugm3)     as no2,
        count(*)          as n_horas_validas,
        max(loaded_at)    as loaded_at
    from hora_local
    {% if is_incremental() %}
    inner join meses_afectados
        using (anno, mes)
    {% endif %}
    where no2_ugm3 is not null
    group by cod_estacion, anno, mes, num_dia_semana, hora

),

{% if is_incremental() %}
combinaciones as (

    -- todas las estación × día × hora de los meses afectados, tengan datos o no
    select
        e.cod_estacion,
        t.anno,
        t.mes,
        {{ num_dia_semana('t.dia_semana') }}   as num_dia_semana,
        t.hora
    from {{ ref('dim_estaciones_no2') }} as e
    cross join {{ ref('dim_tiempo') }} as t
    inner join meses_afectados as m
        on  t.anno = m.anno
        and t.mes = m.mes

),

resultado as (

    select
        c.cod_estacion,
        c.anno,
        c.mes,
        c.num_dia_semana,
        c.hora,
        a.no2,
        coalesce(a.n_horas_validas, 0)                                    as n_horas_validas,
        coalesce(a.loaded_at, (select max(loaded_at) from hora_local))    as loaded_at
    from combinaciones as c
    left join agregado as a
        on  c.cod_estacion = a.cod_estacion
        and c.anno = a.anno
        and c.mes = a.mes
        and c.num_dia_semana = a.num_dia_semana
        and c.hora = a.hora

),
{% else %}
resultado as (

    select * from agregado

),
{% endif %}

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['cod_estacion', 'anno', 'mes', 'num_dia_semana', 'hora']) }}  as id_medida_no2,
        {{ dbt_utils.generate_surrogate_key(['cod_estacion']) }}                                           as id_estacion_no2,
        {{ dbt_utils.generate_surrogate_key(['anno', 'mes', 'num_dia_semana', 'hora']) }}                  as id_tiempo,
        round(no2, 2)                                                                                     as no2,
        n_horas_validas,
        loaded_at
    from resultado

)

select * from final
