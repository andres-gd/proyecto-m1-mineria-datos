-- ========================================
-- PREGUNTA 5: ¿Cuál es el ahorro total generado para nuestros clientes?
-- ========================================
-- Objetivo: Demostrar el valor de la plataforma y justificar comisiones
-- ========================================

-- Query Principal: Dashboard de ahorros del mes actual
WITH ahorros_mensuales AS (
    -- Paso 1: Calcular ahorros por orden
    SELECT 
        f.orden_id,
        f.cliente_id,
        d.fecha,
        d.mes,
        d.nombre_mes,
        -- Métricas de la compra
        SUM(f.cantidad_comprada) as unidades_totales,
        SUM(f.total_pagado) as monto_total_pagado,
        -- Ahorros calculados
        SUM(f.ahorro_vs_promedio) as ahorro_vs_promedio,
        SUM(f.ahorro_vs_maximo) as ahorro_vs_maximo,
        -- Porcentaje de ahorro ponderado
        SUM(f.ahorro_vs_promedio) / NULLIF(SUM(f.precio_promedio_mercado * f.cantidad_comprada), 0) * 100 as porcentaje_ahorro,
        -- Productos únicos
        COUNT(DISTINCT f.producto_id) as productos_diferentes
    FROM fact_compras_ahorro f
    JOIN dim_fecha d ON f.fecha_id = d.fecha_id
    WHERE d.año = EXTRACT(YEAR FROM CURRENT_DATE)
      AND d.mes = EXTRACT(MONTH FROM CURRENT_DATE)
    GROUP BY f.orden_id, f.cliente_id, d.fecha, d.mes, d.nombre_mes
)
SELECT 
    -- Métricas principales
    COUNT(DISTINCT cliente_id) as clientes_activos,
    COUNT(DISTINCT orden_id) as total_ordenes,
    SUM(unidades_totales) as unidades_vendidas,
    
    -- Volumen de negocio
    ROUND(SUM(monto_total_pagado), 2) as gmv_total,
    ROUND(AVG(monto_total_pagado), 2) as ticket_promedio,
    
    -- AHORROS - La métrica estrella
    ROUND(SUM(ahorro_vs_promedio), 2) as ahorro_total_generado,
    ROUND(AVG(ahorro_vs_promedio), 2) as ahorro_promedio_por_orden,
    ROUND(SUM(ahorro_vs_promedio) / COUNT(DISTINCT cliente_id), 2) as ahorro_por_cliente,
    ROUND(AVG(porcentaje_ahorro), 2) || '%' as porcentaje_ahorro_promedio,
    
    -- ROI de la plataforma
    ROUND(SUM(ahorro_vs_promedio) / (SUM(monto_total_pagado) * 0.03), 2) || 'x' as roi_vs_comision_3pct,
    
    -- Distribución de ahorros
    COUNT(CASE WHEN porcentaje_ahorro > 10 THEN 1 END) as ordenes_ahorro_alto,
    COUNT(CASE WHEN porcentaje_ahorro BETWEEN 5 AND 10 THEN 1 END) as ordenes_ahorro_medio,
    COUNT(CASE WHEN porcentaje_ahorro < 5 THEN 1 END) as ordenes_ahorro_bajo
FROM ahorros_mensuales;

-- ========================================
-- Query: Detalle de ahorros por cliente (Top 20)
-- ========================================
WITH ahorros_por_cliente AS (
    SELECT 
        f.cliente_id,
        -- Nombre del cliente (join con dim_cliente si existe)
        'Cliente_' || f.cliente_id as nombre_cliente,
        COUNT(DISTINCT f.orden_id) as numero_ordenes,
        COUNT(DISTINCT d.fecha) as dias_activo,
        SUM(f.cantidad_comprada) as unidades_totales,
        SUM(f.total_pagado) as monto_total_gastado,
        SUM(f.ahorro_vs_promedio) as ahorro_total,
        AVG(f.porcentaje_ahorro) as porcentaje_ahorro_promedio,
        -- Categorización
        CASE 
            WHEN SUM(f.total_pagado) > 100000 THEN 'Enterprise'
            WHEN SUM(f.total_pagado) > 50000 THEN 'Grande'
            WHEN SUM(f.total_pagado) > 20000 THEN 'Mediano'
            ELSE 'Pequeño'
        END as segmento
    FROM fact_compras_ahorro f
    JOIN dim_fecha d ON f.fecha_id = d.fecha_id
    WHERE d.fecha >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY f.cliente_id
)
SELECT 
    nombre_cliente,
    segmento,
    numero_ordenes,
    dias_activo,
    ROUND(monto_total_gastado, 2) as total_gastado,
    ROUND(ahorro_total, 2) as ahorro_generado,
    ROUND(porcentaje_ahorro_promedio, 2) || '%' as ahorro_porcentaje,
    ROUND(ahorro_total / numero_ordenes, 2) as ahorro_por_orden,
    -- Valor lifetime proyectado
    ROUND(ahorro_total / dias_activo * 365, 2) as ahorro_anual_proyectado,
    -- Clasificación
    CASE 
        WHEN ahorro_total > 10000 THEN '⭐⭐⭐ Cliente VIP'
        WHEN ahorro_total > 5000 THEN '⭐⭐ Cliente Valioso'
        ELSE '⭐ Cliente Estándar'
    END as clasificacion
FROM ahorros_por_cliente
ORDER BY ahorro_total DESC
LIMIT 20;

-- ========================================
-- Query: Ahorros por categoría de producto
-- ========================================
SELECT 
    c.nivel1 as categoria_principal,
    c.nivel2 as subcategoria,
    COUNT(DISTINCT f.orden_id) as ordenes,
    SUM(f.cantidad_comprada) as unidades,
    ROUND(SUM(f.total_pagado), 2) as ventas_totales,
    ROUND(SUM(f.ahorro_vs_promedio), 2) as ahorro_total,
    ROUND(AVG(f.porcentaje_ahorro), 2) || '%' as ahorro_promedio_pct,
    -- Insights
    CASE 
        WHEN AVG(f.porcentaje_ahorro) > 15 THEN '🏆 Categoría con máximo ahorro'
        WHEN AVG(f.porcentaje_ahorro) > 10 THEN '✅ Buen ahorro'
        WHEN AVG(f.porcentaje_ahorro) > 5 THEN '📊 Ahorro moderado'
        ELSE '⚠️ Bajo ahorro - Revisar proveedores'
    END as evaluacion,
    -- Top producto que más ahorra
    (SELECT p2.nombre 
     FROM fact_compras_ahorro f2
     JOIN dim_producto p2 ON f2.producto_id = p2.producto_id
     WHERE p2.categoria_id = c.categoria_id
     GROUP BY p2.producto_id, p2.nombre
     ORDER BY SUM(f2.ahorro_vs_promedio) DESC
     LIMIT 1) as producto_estrella_ahorro
FROM fact_compras_ahorro f
JOIN dim_producto p ON f.producto_id = p.producto_id
JOIN dim_categoria c ON p.categoria_id = c.categoria_id
JOIN dim_fecha d ON f.fecha_id = d.fecha_id
WHERE d.fecha >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY c.categoria_id, c.nivel1, c.nivel2
HAVING COUNT(DISTINCT f.orden_id) >= 10
ORDER BY ahorro_total DESC;

-- ========================================
-- Query: Evolución temporal de ahorros
-- ========================================
WITH ahorros_diarios AS (
    SELECT 
        d.fecha,
        d.nombre_dia_semana,
        d.periodo_compra,
        COUNT(DISTINCT f.cliente_id) as clientes_dia,
        COUNT(DISTINCT f.orden_id) as ordenes_dia,
        SUM(f.total_pagado) as ventas_dia,
        SUM(f.ahorro_vs_promedio) as ahorro_dia,
        AVG(f.porcentaje_ahorro) as ahorro_promedio_pct
    FROM fact_compras_ahorro f
    JOIN dim_fecha d ON f.fecha_id = d.fecha_id
    WHERE d.fecha >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY d.fecha, d.nombre_dia_semana, d.periodo_compra
)
SELECT 
    fecha,
    nombre_dia_semana as dia,
    periodo_compra,
    ordenes_dia,
    ROUND(ventas_dia, 2) as ventas,
    ROUND(ahorro_dia, 2) as ahorro_generado,
    ROUND(ahorro_promedio_pct, 2) || '%' as ahorro_pct,
    -- Acumulados
    SUM(ahorro_dia) OVER (ORDER BY fecha) as ahorro_acumulado,
    -- Promedio móvil 7 días
    ROUND(AVG(ahorro_dia) OVER (ORDER BY fecha ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) as ahorro_promedio_7d,
    -- Comparación con promedio
    CASE 
        WHEN ahorro_dia > AVG(ahorro_dia) OVER () * 1.2 THEN '📈 Día excepcional'
        WHEN ahorro_dia < AVG(ahorro_dia) OVER () * 0.8 THEN '📉 Día bajo'
        ELSE '➡️ Día normal'
    END as performance_dia
FROM ahorros_diarios
ORDER BY fecha DESC;

-- ========================================
-- Query: Proyección anual y métricas de valor
-- ========================================
WITH metricas_actuales AS (
    SELECT 
        -- Métricas del mes actual
        COUNT(DISTINCT cliente_id) as clientes_mes_actual,
        SUM(total_pagado) as gmv_mes_actual,
        SUM(ahorro_vs_promedio) as ahorro_mes_actual,
        AVG(porcentaje_ahorro) as ahorro_pct_promedio
    FROM fact_compras_ahorro f
    JOIN dim_fecha d ON f.fecha_id = d.fecha_id
    WHERE d.año = EXTRACT(YEAR FROM CURRENT_DATE)
      AND d.mes = EXTRACT(MONTH FROM CURRENT_DATE)
),
metricas_historicas AS (
    SELECT 
        -- Crecimiento mes a mes
        AVG(CASE WHEN d.mes = EXTRACT(MONTH FROM CURRENT_DATE) - 1 
            THEN 1 ELSE 0 END) as mes_anterior
    FROM fact_compras_ahorro f
    JOIN dim_fecha d ON f.fecha_id = d.fecha_id
)
SELECT 
    -- Métricas actuales
    clientes_mes_actual as clientes_activos,
    ROUND(gmv_mes_actual, 2) as ventas_mes_actual,
    ROUND(ahorro_mes_actual, 2) as ahorro_mes_actual,
    ROUND(ahorro_pct_promedio, 2) || '%' as ahorro_promedio,
    
    -- Proyecciones anuales (simple: mes * 12)
    clientes_mes_actual * 12 as clientes_proyeccion_anual,
    ROUND(gmv_mes_actual * 12, 2) as gmv_proyeccion_anual,
    ROUND(ahorro_mes_actual * 12, 2) as ahorro_total_anual_proyectado,
    
    -- Valor generado
    ROUND(ahorro_mes_actual * 12 / (gmv_mes_actual * 12 * 0.03), 2) || 'x' as multiplicador_valor_vs_comision,
    
    -- Impacto por cliente
    ROUND(ahorro_mes_actual / clientes_mes_actual, 2) as ahorro_mensual_por_cliente,
    ROUND(ahorro_mes_actual * 12 / clientes_mes_actual, 2) as ahorro_anual_por_cliente,
    
    -- Mensaje de valor
    'Con Rappi B2B, nuestros ' || clientes_mes_actual || ' clientes ahorraron $' || 
    TO_CHAR(ahorro_mes_actual, 'FM999,999,999') || ' este mes. ' ||
    'Proyectamos un ahorro anual de $' || TO_CHAR(ahorro_mes_actual * 12, 'FM999,999,999') || 
    ' para nuestros clientes.' as mensaje_ejecutivo
FROM metricas_actuales;

-- ========================================
-- Query: Casos de éxito - Mejores ahorros individuales
-- ========================================
SELECT 
    'Orden #' || f.orden_id as orden,
    d.fecha,
    p.nombre as producto,
    pr.nombre as proveedor,
    f.cantidad_comprada as cantidad,
    ROUND(f.precio_unitario_pagado, 2) as precio_pagado,
    ROUND(f.precio_promedio_mercado, 2) as precio_mercado,
    ROUND(f.ahorro_vs_promedio, 2) as ahorro_generado,
    ROUND(f.porcentaje_ahorro, 2) || '%' as porcentaje_ahorro,
    '💰 El cliente ahorró $' || ROUND(f.ahorro_vs_promedio, 2) || 
    ' (' || ROUND(f.porcentaje_ahorro, 1) || '%) comprando ' || 
    p.nombre || ' con ' || pr.nombre as historia_exito
FROM fact_compras_ahorro f
JOIN dim_producto p ON f.producto_id = p.producto_id
JOIN dim_proveedor pr ON f.proveedor_id = pr.proveedor_id
JOIN dim_fecha d ON f.fecha_id = d.fecha_id
WHERE d.fecha >= CURRENT_DATE - INTERVAL '7 days'
  AND f.porcentaje_ahorro > 15  -- Solo grandes ahorros
ORDER BY f.ahorro_vs_promedio DESC
LIMIT 10;
