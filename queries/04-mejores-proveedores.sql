-- ========================================
-- PREGUNTA 4: ¿Qué proveedores ofrecen los mejores precios?
-- ========================================
-- Objetivo: Identificar proveedores más competitivos para fortalecer relaciones
-- ========================================

-- Query Principal: Ranking general de proveedores
WITH metricas_proveedor AS (
    -- Paso 1: Calcular métricas clave por proveedor
    SELECT 
        p.proveedor_id,
        p.nombre as proveedor,
        p.tipo,
        p.nivel_precio as nivel_declarado,
        p.calificacion,
        COUNT(DISTINCT f.producto_id) as productos_ofrecidos,
        COUNT(DISTINCT f.fecha_id) as dias_activo,
        -- Métricas de precio
        AVG(f.precio_venta) as precio_promedio,
        AVG(f.precio_venta / NULLIF(f.precio_promedio_mercado, 0)) as indice_precio, -- <1 = más barato que mercado
        -- Frecuencia de mejor precio
        SUM(CASE WHEN f.es_precio_mas_bajo THEN 1 ELSE 0 END) as veces_mejor_precio,
        COUNT(*) as total_registros,
        SUM(CASE WHEN f.es_precio_mas_bajo THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100 as pct_mejor_precio,
        -- Disponibilidad
        AVG(CASE WHEN f.tiene_stock THEN 1 ELSE 0 END) * 100 as disponibilidad_pct,
        -- Competitividad por categoría
        COUNT(DISTINCT c.nivel1) as categorias_cubiertas
    FROM fact_precio_diario f
    JOIN dim_proveedor p ON f.proveedor_id = p.proveedor_id
    JOIN dim_categoria c ON f.categoria_id = c.categoria_id
    WHERE f.fecha_id >= TO_NUMBER(TO_CHAR(CURRENT_DATE - INTERVAL '30 days', 'YYYYMMDD'))
      AND p.activo = true
    GROUP BY p.proveedor_id, p.nombre, p.tipo, p.nivel_precio, p.calificacion
),
ranking_final AS (
    -- Paso 2: Calcular scores y rankings
    SELECT 
        *,
        -- Score compuesto (precio 50%, disponibilidad 30%, variedad 20%)
        (
            (CASE WHEN indice_precio < 1 THEN (1 - indice_precio) * 100 ELSE 0 END) * 0.5 +  -- Precio
            disponibilidad_pct * 0.3 +                                                         -- Disponibilidad
            LEAST(productos_ofrecidos / 10.0, 100) * 0.2                                      -- Variedad
        ) as score_total,
        -- Rankings individuales
        RANK() OVER (ORDER BY indice_precio) as ranking_precio,
        RANK() OVER (ORDER BY disponibilidad_pct DESC) as ranking_disponibilidad,
        RANK() OVER (ORDER BY productos_ofrecidos DESC) as ranking_variedad
    FROM metricas_proveedor
    WHERE productos_ofrecidos >= 20  -- Mínimo catálogo significativo
)
SELECT 
    proveedor,
    tipo,
    nivel_declarado,
    ROUND(calificacion, 1) as calificacion_servicio,
    productos_ofrecidos,
    categorias_cubiertas,
    -- Métricas de precio
    ROUND(indice_precio, 3) as indice_precio,
    CASE 
        WHEN indice_precio < 0.95 THEN '🏆 Líder en precio'
        WHEN indice_precio < 1.00 THEN '✅ Competitivo'
        WHEN indice_precio < 1.05 THEN '⚠️ Ligeramente caro'
        ELSE '❌ Premium/Caro'
    END as posicion_precio,
    ROUND(pct_mejor_precio, 1) || '%' as frecuencia_mejor_precio,
    -- Disponibilidad
    ROUND(disponibilidad_pct, 1) || '%' as disponibilidad,
    -- Score y ranking final
    ROUND(score_total, 1) as score_total,
    RANK() OVER (ORDER BY score_total DESC) as ranking_general,
    -- Recomendación
    CASE 
        WHEN RANK() OVER (ORDER BY score_total DESC) <= 3 THEN '⭐⭐⭐ Proveedor estratégico'
        WHEN RANK() OVER (ORDER BY score_total DESC) <= 10 THEN '⭐⭐ Proveedor importante'
        WHEN indice_precio > 1.10 THEN '⚠️ Revisar relación'
        ELSE '⭐ Proveedor estándar'
    END as clasificacion
FROM ranking_final
ORDER BY score_total DESC
LIMIT 20;

-- ========================================
-- Query: Mejores proveedores por categoría
-- ========================================
WITH proveedor_categoria AS (
    SELECT 
        c.nivel1 as categoria,
        p.nombre as proveedor,
        COUNT(DISTINCT f.producto_id) as productos,
        AVG(f.precio_venta / NULLIF(f.precio_promedio_mercado, 0)) as indice_precio,
        SUM(CASE WHEN f.es_precio_mas_bajo THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100 as pct_mejor_precio,
        AVG(CASE WHEN f.tiene_stock THEN 1 ELSE 0 END) * 100 as disponibilidad
    FROM fact_precio_diario f
    JOIN dim_proveedor p ON f.proveedor_id = p.proveedor_id
    JOIN dim_categoria c ON f.categoria_id = c.categoria_id
    WHERE f.fecha_id >= TO_NUMBER(TO_CHAR(CURRENT_DATE - INTERVAL '30 days', 'YYYYMMDD'))
      AND p.activo = true
    GROUP BY c.nivel1, p.nombre, p.proveedor_id
    HAVING COUNT(DISTINCT f.producto_id) >= 10
)
SELECT 
    categoria,
    proveedor,
    productos as productos_en_categoria,
    ROUND(indice_precio, 3) as indice_precio,
    ROUND(pct_mejor_precio, 1) || '%' as lider_precio_pct,
    ROUND(disponibilidad, 1) || '%' as disponibilidad,
    RANK() OVER (PARTITION BY categoria ORDER BY indice_precio) as ranking_en_categoria,
    CASE 
        WHEN RANK() OVER (PARTITION BY categoria ORDER BY indice_precio) = 1 THEN '🥇 Mejor en ' || categoria
        WHEN RANK() OVER (PARTITION BY categoria ORDER BY indice_precio) = 2 THEN '🥈 Segundo mejor'
        WHEN RANK() OVER (PARTITION BY categoria ORDER BY indice_precio) = 3 THEN '🥉 Tercero'
        ELSE ''
    END as medalla
FROM proveedor_categoria
WHERE RANK() OVER (PARTITION BY categoria ORDER BY indice_precio) <= 5
ORDER BY categoria, ranking_en_categoria;

-- ========================================
-- Query: Análisis de competitividad detallado
-- ========================================
WITH competitividad AS (
    SELECT 
        p1.nombre as proveedor,
        p2.nombre as competidor,
        COUNT(DISTINCT CASE WHEN f1.precio_venta < f2.precio_venta THEN f1.producto_id END) as productos_mas_barato,
        COUNT(DISTINCT CASE WHEN f1.precio_venta > f2.precio_venta THEN f1.producto_id END) as productos_mas_caro,
        COUNT(DISTINCT CASE WHEN ABS(f1.precio_venta - f2.precio_venta) < 1 THEN f1.producto_id END) as productos_similar,
        COUNT(DISTINCT f1.producto_id) as productos_comparados,
        AVG((f1.precio_venta - f2.precio_venta) / NULLIF(f2.precio_venta, 0) * 100) as diferencia_precio_promedio
    FROM fact_precio_diario f1
    JOIN fact_precio_diario f2 
        ON f1.producto_id = f2.producto_id 
        AND f1.fecha_id = f2.fecha_id
        AND f1.proveedor_id != f2.proveedor_id
    JOIN dim_proveedor p1 ON f1.proveedor_id = p1.proveedor_id
    JOIN dim_proveedor p2 ON f2.proveedor_id = p2.proveedor_id
    WHERE f1.fecha_id = TO_NUMBER(TO_CHAR(CURRENT_DATE, 'YYYYMMDD'))
      AND p1.nombre IN ('Costco Business', 'Restaurant Depot')  -- Principales competidores
      AND p2.nombre IN ('Costco Business', 'Restaurant Depot')
      AND p1.nombre != p2.nombre
    GROUP BY p1.nombre, p2.nombre
)
SELECT 
    proveedor,
    'vs ' || competidor as versus,
    productos_comparados as productos_en_comun,
    productos_mas_barato || ' (' || ROUND(productos_mas_barato::FLOAT / productos_comparados * 100, 1) || '%)' as gana_en,
    productos_mas_caro || ' (' || ROUND(productos_mas_caro::FLOAT / productos_comparados * 100, 1) || '%)' as pierde_en,
    ROUND(diferencia_precio_promedio, 2) || '%' as diferencia_promedio,
    CASE 
        WHEN productos_mas_barato > productos_mas_caro THEN '✅ Más competitivo'
        ELSE '❌ Menos competitivo'
    END as conclusion
FROM competitividad;

-- ========================================
-- Query: Tendencia de competitividad (últimos 30 días)
-- ========================================
WITH tendencia_diaria AS (
    SELECT 
        p.nombre as proveedor,
        d.fecha,
        AVG(f.precio_venta / NULLIF(f.precio_promedio_mercado, 0)) as indice_precio_dia,
        SUM(CASE WHEN f.es_precio_mas_bajo THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100 as pct_mejor_precio_dia
    FROM fact_precio_diario f
    JOIN dim_proveedor p ON f.proveedor_id = p.proveedor_id
    JOIN dim_fecha d ON f.fecha_id = d.fecha_id
    WHERE d.fecha >= CURRENT_DATE - INTERVAL '30 days'
      AND p.nombre IN (
          SELECT nombre 
          FROM dim_proveedor 
          WHERE activo = true 
          ORDER BY calificacion DESC 
          LIMIT 5
      )
    GROUP BY p.nombre, d.fecha
)
SELECT 
    proveedor,
    MIN(fecha) as periodo_desde,
    MAX(fecha) as periodo_hasta,
    ROUND(AVG(indice_precio_dia), 3) as indice_promedio_periodo,
    ROUND(MIN(indice_precio_dia), 3) as mejor_indice,
    ROUND(MAX(indice_precio_dia), 3) as peor_indice,
    -- Tendencia
    CASE 
        WHEN AVG(CASE WHEN fecha >= CURRENT_DATE - 7 THEN indice_precio_dia END) < 
             AVG(CASE WHEN fecha < CURRENT_DATE - 7 THEN indice_precio_dia END) 
        THEN '📈 Mejorando precios'
        WHEN AVG(CASE WHEN fecha >= CURRENT_DATE - 7 THEN indice_precio_dia END) > 
             AVG(CASE WHEN fecha < CURRENT_DATE - 7 THEN indice_precio_dia END) 
        THEN '📉 Subiendo precios'
        ELSE '→ Estable'
    END as tendencia_reciente,
    ROUND(AVG(pct_mejor_precio_dia), 1) || '%' as promedio_liderazgo
FROM tendencia_diaria
GROUP BY proveedor
ORDER BY indice_promedio_periodo;

-- ========================================
-- Query: Recomendaciones de negociación
-- ========================================
SELECT 
    p.nombre as proveedor,
    p.tipo,
    COUNT(DISTINCT f.producto_id) as productos,
    ROUND(AVG(f.precio_venta), 2) as ticket_promedio,
    -- Volumen estimado mensual
    COUNT(DISTINCT f.fecha_id) * COUNT(DISTINCT f.producto_id) * 10 as volumen_estimado_mensual,
    -- Poder de negociación
    CASE 
        WHEN COUNT(DISTINCT f.producto_id) > 500 THEN 'Alto volumen - Exigir descuentos por volumen'
        WHEN AVG(f.precio_venta / NULLIF(f.precio_promedio_mercado, 0)) > 1.05 THEN 'Precios altos - Negociar reducción'
        WHEN p.calificacion < 4.0 THEN 'Servicio mejorable - Exigir mejoras o descuentos'
        WHEN SUM(CASE WHEN f.tiene_stock THEN 1 ELSE 0 END)::FLOAT / COUNT(*) < 0.90 THEN 'Baja disponibilidad - Mejorar stock'
        ELSE 'Relación balanceada - Mantener términos'
    END as estrategia_negociacion,
    -- Prioridad
    CASE 
        WHEN COUNT(DISTINCT f.producto_id) > 500 THEN 'ALTA'
        WHEN COUNT(DISTINCT f.producto_id) > 200 THEN 'MEDIA'
        ELSE 'BAJA'
    END as prioridad_negociacion
FROM fact_precio_diario f
JOIN dim_proveedor p ON f.proveedor_id = p.proveedor_id
WHERE f.fecha_id >= TO_NUMBER(TO_CHAR(CURRENT_DATE - INTERVAL '30 days', 'YYYYMMDD'))
  AND p.activo = true
GROUP BY p.proveedor_id, p.nombre, p.tipo, p.calificacion
HAVING COUNT(DISTINCT f.producto_id) >= 50
ORDER BY COUNT(DISTINCT f.producto_id) DESC;
