-- ========================================
-- PREGUNTA 3: ¿Cuáles son los mejores momentos para comprar por categoría?
-- ========================================
-- Objetivo: Identificar patrones temporales para optimizar calendario de compras
-- ========================================

-- Query Principal: Mejores días del mes por categoría
WITH patron_mensual AS (
    -- Paso 1: Analizar precios por día del mes
    SELECT 
        c.nivel1 as categoria_principal,
        c.nivel2 as subcategoria,
        d.dia as dia_del_mes,
        d.periodo_compra,
        COUNT(DISTINCT f.producto_id) as productos_analizados,
        AVG(f.precio_venta) as precio_promedio_dia,
        AVG(f.precio_promedio_mercado) as precio_mercado_dia,
        -- Cuántos productos están en su precio más bajo
        SUM(CASE WHEN f.es_precio_mas_bajo THEN 1 ELSE 0 END) as productos_precio_minimo,
        -- Disponibilidad
        AVG(CASE WHEN f.tiene_stock THEN 1 ELSE 0 END) * 100 as disponibilidad_pct
    FROM fact_precio_diario f
    JOIN dim_categoria c ON f.categoria_id = c.categoria_id
    JOIN dim_fecha d ON f.fecha_id = d.fecha_id
    WHERE d.fecha >= CURRENT_DATE - INTERVAL '90 days'  -- Últimos 3 meses
    GROUP BY c.nivel1, c.nivel2, d.dia, d.periodo_compra
),
ranking_dias AS (
    -- Paso 2: Rankear días por precio
    SELECT 
        *,
        -- Ranking del día más barato al más caro
        RANK() OVER (PARTITION BY categoria_principal, subcategoria ORDER BY precio_promedio_dia) as ranking_precio,
        -- Precio mínimo y máximo del mes para esta categoría
        MIN(precio_promedio_dia) OVER (PARTITION BY categoria_principal, subcategoria) as precio_min_mes,
        MAX(precio_promedio_dia) OVER (PARTITION BY categoria_principal, subcategoria) as precio_max_mes
    FROM patron_mensual
    WHERE productos_analizados >= 10  -- Suficientes datos
)
SELECT 
    categoria_principal,
    subcategoria,
    dia_del_mes,
    periodo_compra,
    ROUND(precio_promedio_dia, 2) as precio_promedio,
    ranking_precio,
    -- Ahorro potencial vs peor día
    ROUND(precio_max_mes - precio_promedio_dia, 2) as ahorro_vs_peor_dia,
    ROUND((precio_max_mes - precio_promedio_dia) / precio_max_mes * 100, 2) as ahorro_potencial_pct,
    -- Recomendación
    CASE 
        WHEN ranking_precio <= 5 THEN '🏆 MEJOR MOMENTO'
        WHEN ranking_precio <= 10 THEN '✅ Buen momento'
        WHEN ranking_precio >= 26 THEN '❌ EVITAR'
        ELSE '➖ Regular'
    END as recomendacion,
    ROUND(disponibilidad_pct, 1) as disponibilidad,
    productos_analizados
FROM ranking_dias
WHERE ranking_precio <= 5 OR ranking_precio >= 26  -- Solo mejores y peores días
ORDER BY categoria_principal, subcategoria, ranking_precio;

-- ========================================
-- Query: Mejor día de la semana
-- ========================================
WITH patron_semanal AS (
    SELECT 
        c.nivel2 as categoria,
        d.nombre_dia_semana,
        CASE d.nombre_dia_semana
            WHEN 'Monday' THEN 1
            WHEN 'Tuesday' THEN 2
            WHEN 'Wednesday' THEN 3
            WHEN 'Thursday' THEN 4
            WHEN 'Friday' THEN 5
            WHEN 'Saturday' THEN 6
            WHEN 'Sunday' THEN 7
        END as dia_numero,
        COUNT(DISTINCT f.fecha_id) as dias_analizados,
        AVG(f.precio_venta) as precio_promedio,
        STDDEV(f.precio_venta) as desviacion_precio,
        AVG(CASE WHEN f.tiene_stock THEN 1 ELSE 0 END) * 100 as disponibilidad
    FROM fact_precio_diario f
    JOIN dim_categoria c ON f.categoria_id = c.categoria_id
    JOIN dim_fecha d ON f.fecha_id = d.fecha_id
    WHERE d.fecha >= CURRENT_DATE - INTERVAL '90 days'
      AND d.es_dia_festivo = false  -- Excluir festivos
    GROUP BY c.nivel2, d.nombre_dia_semana
)
SELECT 
    categoria,
    nombre_dia_semana as dia,
    ROUND(precio_promedio, 2) as precio_promedio,
    RANK() OVER (PARTITION BY categoria ORDER BY precio_promedio) as ranking,
    ROUND(precio_promedio - MIN(precio_promedio) OVER (PARTITION BY categoria), 2) as diferencia_vs_mejor,
    ROUND(disponibilidad, 1) as disponibilidad_pct,
    -- Visual
    CASE 
        WHEN RANK() OVER (PARTITION BY categoria ORDER BY precio_promedio) = 1 THEN '🥇 Mejor día'
        WHEN RANK() OVER (PARTITION BY categoria ORDER BY precio_promedio) = 2 THEN '🥈 Segundo mejor'
        WHEN RANK() OVER (PARTITION BY categoria ORDER BY precio_promedio) >= 6 THEN '❌ Evitar'
        ELSE '➖ Regular'
    END as recomendacion
FROM patron_semanal
WHERE dias_analizados >= 10
ORDER BY categoria, dia_numero;

-- ========================================
-- Query: Patrones por período del mes
-- ========================================
SELECT 
    c.nivel1 as categoria,
    d.periodo_compra,
    COUNT(DISTINCT f.producto_id) as productos,
    COUNT(DISTINCT f.fecha_id) as dias_analizados,
    -- Métricas de precio
    ROUND(AVG(f.precio_venta), 2) as precio_promedio,
    ROUND(MIN(AVG(f.precio_venta)) OVER (PARTITION BY c.nivel1), 2) as mejor_precio_categoria,
    -- Comparación
    ROUND(AVG(f.precio_venta) - MIN(AVG(f.precio_venta)) OVER (PARTITION BY c.nivel1), 2) as sobreprecio,
    ROUND((AVG(f.precio_venta) / MIN(AVG(f.precio_venta)) OVER (PARTITION BY c.nivel1) - 1) * 100, 2) as sobreprecio_pct,
    -- Insights
    CASE d.periodo_compra
        WHEN 'inicio_mes' THEN 'Presupuestos frescos, buena disponibilidad'
        WHEN 'quincena' THEN 'Alta demanda, precios elevados'
        WHEN 'fin_mes' THEN 'Liquidaciones pero menor disponibilidad'
        ELSE 'Período estable'
    END as caracteristicas,
    -- Recomendación
    CASE 
        WHEN AVG(f.precio_venta) = MIN(AVG(f.precio_venta)) OVER (PARTITION BY c.nivel1) THEN '🎯 COMPRAR'
        WHEN (AVG(f.precio_venta) / MIN(AVG(f.precio_venta)) OVER (PARTITION BY c.nivel1) - 1) > 0.10 THEN '🚫 EVITAR'
        ELSE '✅ Aceptable'
    END as accion_recomendada
FROM fact_precio_diario f
JOIN dim_categoria c ON f.categoria_id = c.categoria_id
JOIN dim_fecha d ON f.fecha_id = d.fecha_id
WHERE d.fecha >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY c.nivel1, d.periodo_compra
ORDER BY categoria, 
         CASE d.periodo_compra 
             WHEN 'inicio_mes' THEN 1
             WHEN 'regular' THEN 2
             WHEN 'quincena' THEN 3
             WHEN 'fin_mes' THEN 4
         END;

-- ========================================
-- Query: Calendario de compras óptimas (próximos 30 días)
-- ========================================
WITH promedios_historicos AS (
    -- Calcular el promedio histórico por día del mes y categoría
    SELECT 
        c.nivel2 as categoria,
        d.dia as dia_del_mes,
        AVG(f.precio_venta) as precio_promedio_historico,
        RANK() OVER (PARTITION BY c.nivel2 ORDER BY AVG(f.precio_venta)) as ranking_historico
    FROM fact_precio_diario f
    JOIN dim_categoria c ON f.categoria_id = c.categoria_id
    JOIN dim_fecha d ON f.fecha_id = d.fecha_id
    WHERE d.fecha >= CURRENT_DATE - INTERVAL '90 days'
    GROUP BY c.nivel2, d.dia
)
SELECT 
    df.fecha,
    df.nombre_dia_semana as dia_semana,
    df.dia as dia_mes,
    ph.categoria,
    ROUND(ph.precio_promedio_historico, 2) as precio_esperado,
    ph.ranking_historico,
    CASE 
        WHEN ph.ranking_historico <= 5 THEN '🟢 Día óptimo para comprar'
        WHEN ph.ranking_historico <= 10 THEN '🟡 Día aceptable'
        WHEN df.es_quincena THEN '🔴 Evitar - Quincena'
        WHEN ph.ranking_historico >= 25 THEN '🔴 Evitar - Históricamente caro'
        ELSE '⚪ Día regular'
    END as recomendacion,
    CASE 
        WHEN ph.ranking_historico <= 5 THEN 3  -- Prioridad alta
        WHEN ph.ranking_historico <= 10 THEN 2  -- Prioridad media
        ELSE 1  -- Prioridad baja
    END as prioridad_compra
FROM dim_fecha df
CROSS JOIN (SELECT DISTINCT nivel2 as categoria FROM dim_categoria WHERE nivel1 = 'Alimentos') c
LEFT JOIN promedios_historicos ph ON ph.categoria = c.categoria AND ph.dia_del_mes = df.dia
WHERE df.fecha BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'
  AND ph.ranking_historico <= 10  -- Solo mostrar días buenos
ORDER BY df.fecha, prioridad_compra DESC, ph.categoria;

-- ========================================
-- Query: Resumen ejecutivo de mejores momentos
-- ========================================
WITH resumen AS (
    SELECT 
        c.nivel1 as categoria,
        -- Mejor día del mes
        (SELECT dia_del_mes 
         FROM fact_precio_diario f2 
         JOIN dim_fecha d2 ON f2.fecha_id = d2.fecha_id 
         WHERE f2.categoria_id = f.categoria_id 
         GROUP BY d2.dia 
         ORDER BY AVG(f2.precio_venta) 
         LIMIT 1) as mejor_dia_mes,
        -- Mejor día de la semana
        (SELECT d3.nombre_dia_semana 
         FROM fact_precio_diario f3 
         JOIN dim_fecha d3 ON f3.fecha_id = d3.fecha_id 
         WHERE f3.categoria_id = f.categoria_id 
         GROUP BY d3.nombre_dia_semana 
         ORDER BY AVG(f3.precio_venta) 
         LIMIT 1) as mejor_dia_semana,
        -- Mejor período
        (SELECT d4.periodo_compra 
         FROM fact_precio_diario f4 
         JOIN dim_fecha d4 ON f4.fecha_id = d4.fecha_id 
         WHERE f4.categoria_id = f.categoria_id 
         GROUP BY d4.periodo_compra 
         ORDER BY AVG(f4.precio_venta) 
         LIMIT 1) as mejor_periodo,
        -- Ahorro potencial
        ROUND((MAX(f.precio_venta) - MIN(f.precio_venta)) / MAX(f.precio_venta) * 100, 2) as ahorro_potencial_pct
    FROM fact_precio_diario f
    JOIN dim_categoria c ON f.categoria_id = c.categoria_id
    GROUP BY c.nivel1, f.categoria_id
)
SELECT 
    categoria,
    mejor_dia_mes || ' del mes' as mejor_dia_mes,
    mejor_dia_semana,
    CASE mejor_periodo
        WHEN 'inicio_mes' THEN 'Primeros 10 días'
        WHEN 'regular' THEN 'Días 11-13, 17-25'
        WHEN 'quincena' THEN 'Días 14-16 (Evitar)'
        WHEN 'fin_mes' THEN 'Últimos 5 días'
    END as mejor_periodo,
    ahorro_potencial_pct || '%' as ahorro_maximo_posible
FROM resumen
ORDER BY categoria;
