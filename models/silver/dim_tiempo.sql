{#-
    Dimensión de tiempo al grano del perfil de tráfico: año × mes × día de la semana.
    7 años × 12 meses × 7 días = 588 filas.
    n_dias (cuántos lunes, martes... tiene ese mes) es el denominador de la cobertura
    del NO2; n_festivos indica cuántos de esos días fueron festivo en Granada.
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
        d.date_day::date                       as fecha,
        year(d.date_day)                       as anno,
        month(d.date_day)                      as mes,
        dayofweekiso(d.date_day)               as num_dia_semana,
        f.fecha is not null                    as es_festivo
    from dias as d
    left join festivos as f
        on d.date_day::date = f.fecha

),

agregado as (

    select
        anno,
        mes,
        num_dia_semana,
        count(*)               as n_dias,
        count_if(es_festivo)   as n_festivos
    from calendario
    group by anno, mes, num_dia_semana

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['anno', 'mes', 'num_dia_semana']) }}  as id_tiempo,
        anno,
        mes,
        decode(num_dia_semana,
            1, 'lun', 2, 'mar', 3, 'mie', 4, 'jue',
            5, 'vie', 6, 'sab', 7, 'dom')                                        as dia_semana,
        num_dia_semana,
        iff(num_dia_semana <= 5, 'laborable', 'fin_de_semana')                   as tipo_dia,
        date_from_parts(anno, mes, 1)                                            as fecha_mes,
        n_dias,
        n_festivos
    from agregado

)

select * from final
