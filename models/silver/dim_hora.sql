{#-
    Dimensión de hora: tipo de día × hora (2 × 24 = 48 filas).
    La misma hora tiene un id distinto en laborable y en fin de semana porque
    las franjas horarias cambian (seed_franjas_horarias).
    hora = 1..24, la hora que termina a esa hora local (1 = 00:00-01:00).
-#}

with horas as (

    select row_number() over (order by seq4()) as hora
    from table(generator(rowcount => 24))

),

franjas as (

    select * from {{ ref('seed_franjas_horarias') }}

),

tipos_dia as (

    select distinct tipo_dia from franjas

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['t.tipo_dia', 'h.hora']) }}  as id_hora,
        t.tipo_dia,
        h.hora,
        f.franja                                                        as franja_horaria,
        f.orden_franja
    from tipos_dia as t
    cross join horas as h
    left join franjas as f
        on  f.tipo_dia = t.tipo_dia
        and h.hora between f.hora_inicio and f.hora_fin

)

select * from final
