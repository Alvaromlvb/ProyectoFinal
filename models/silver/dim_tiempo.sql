{#-
    Dimensión de tiempo al grano de las dos tablas de hechos:
    año × mes × día de la semana × hora (7 × 12 × 7 × 24 = 14.112 filas).

    hora = 1..24, hora local en que termina el intervalo (1 = 00:00-01:00).
    n_dias: cuántos días de ese tipo (lunes, martes...) tiene el mes. Es el denominador
    de la cobertura del NO2 (n_horas_validas / n_dias).
    n_festivos: cuántos de esos días fueron festivo en Granada (el perfil de tráfico
    del Ayuntamiento los incluye en la media).
-#}

with dias as (

    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="'2015-01-01'::date",
        end_date="'2022-01-01'::date"
    ) }}

),

festivos as (

    select fecha from {{ ref('seed_festivos') }}

),

calendario as (

    select
        year(d.date_day)               as anno,
        month(d.date_day)              as mes,
        dayofweekiso(d.date_day)       as num_dia_semana,
        f.fecha is not null            as es_festivo
    from dias as d
    left join festivos as f
        on d.date_day::date = f.fecha

),

dias_mes as (

    select
        anno,
        mes,
        num_dia_semana,
        count(*)               as n_dias,
        count_if(es_festivo)   as n_festivos
    from calendario
    group by anno, mes, num_dia_semana

),

horas as (

    select row_number() over (order by seq4()) as hora
    from table(generator(rowcount => 24))

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['d.anno', 'd.mes', 'd.num_dia_semana', 'h.hora']) }}  as id_tiempo,
        d.anno,
        d.mes,
        {{ nombre_dia_semana('d.num_dia_semana') }}                                         as dia_semana,
        h.hora,
        iff(d.num_dia_semana <= 5, 'laborable', 'fin_de_semana')                            as tipo_dia,
        d.n_dias,
        d.n_festivos
    from dias_mes as d
    cross join horas as h

)

select * from final
