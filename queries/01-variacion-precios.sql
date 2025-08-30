-- ========================================
-- PREGUNTA 1: ¿Cuál es la variación del precio promedio por categoría?
-- ========================================
-- Objetivo: Identificar categorías con mayor inflación para ajustar presupuestos
-- ========================================

-- Query Principal: Variación mensual por categoría
WITH precios_mensuales AS (
    -- Paso 1: Calcular precio promedio por categoría y mes
    SELECT 
        c.nivel1 as categoria_principal,
        c.nivel2 as subcategoria,
        d.año,
        d.mes,
        d.nombre_mes,
        COUNT(DISTINCT f.producto_id) as productos_analizados,
        AVG(f.precio_venta) as precio_promedio,
        MIN(f.precio_venta) as precio_minimo,
        MAX(f.precio_venta) as precio_maximo
    FROM fact_precio_diario f
    JOIN dim_categoria c ON f.categoria_id = c.categoria_id
    JOIN dim_fecha d ON f.fecha_id = d.fecha_id
    WHERE f.tiene_stock = true  -- Solo considerar productos disponibles
      AND d.año = 2024
    GROUP BY c.nivel1, c.nivel2, d.año, d.mes, d.nombre_mes
)
-- Paso 2: Calcular variación mes a mes
SELECT 
    categoria_principal,
    subcategoria,
    nombre_mes,
    precio_promedio as precio_actual,
    LAG(precio_promedio) OVER (PARTITION BY categoria_principal, subcategoria ORDER BY año, mes) as precio_mes_anterior,
    -- Variación absoluta
    precio_promedio - LAG(precio_promedio) OVER (PARTITION BY categoria_principal, subcategoria ORDER BY año, mes) as variacion_pesos,
    -- Variación porcentual
    ROUND(
        ((precio_promedio - LAG(precio_promedio) OVER (PARTITION BY categoria_principal, subcategoria ORDER BY año, mes)) 
        / LAG(precio_promedio) OVER (PARTITION BY categoria_principal, subcategoria ORDER BY año, mes)) * 100, 
    2) as variacion_porcentaje,
    -- Indicador visual
    CASE 
        WHEN ((precio_promedio - LAG(precio_promedio) OVER (PARTITION BY categoria_principal, subcategoria ORDER BY año, mes)) 
              / LAG(precio_promedio) OVER (PARTITION BY categoria_principal, subcategoria ORDER BY año, mes)) > 0.05 THEN '🔴 Subida Alta'
        WHEN ((precio_promedio - LAG(precio_promedio) OVER (PARTITION BY categoria_principal, subcategoria ORDER BY año, mes)) 
              / LAG(precio_promedio) OVER (PARTITION BY categoria_principal, subcategoria ORDER BY año, mes)) > 0.02 THEN '🟡 Subida Moderada'
        WHEN ((precio_promedio - LAG(precio_promedio) OVER (PARTITION BY categoria_principal, subcategoria ORDER BY año, mes)) 
              / LAG(precio_promedio) OVER (PARTITION BY categoria_principal, subcategoria ORDER BY año, mes)) > -0.02 THEN '🟢 Estable'
        WHEN ((precio_promedio - LAG(precio_promedio) OVER (PARTITION BY categoria_principal, subcategoria ORDER BY año, mes)) 
              / LAG(precio_promedio) OVER (PARTITION BY categoria_principal, subcategoria ORDER BY año, mes)) > -0.05 THEN '🔵 Bajada Moderada'
        ELSE '💚 Bajada Significativa'
    END as tendencia,
    productos_analizados
FROM precios_mensuales
WHERE precio_mes_anterior IS NOT NULL  -- Excluir primer mes sin comparación
ORDER BY categoria_principal, subcategoria, año, mes;

-- ========================================
-- Query Alternativa: Top 10 categorías con mayor aumento
-- ========================================
WITH variaciones AS (
    SELECT 
        c.nivel2 as categoria,
        AVG(CASE WHEN d.mes = 1 THEN f.precio_venta END) as precio_enero,
        AVG(CASE WHEN d.mes = 2 THEN f.precio_venta END) as precio_febrero,
        COUNT(DISTINCT f.producto_id) as productos
    FROM fact_precio_diario f
    JOIN dim_categoria c ON f.categoria_id = c.categoria_id
    JOIN dim_fecha d ON f.fecha_id = d.fecha_id
    WHERE d.año = 2024 
      AND d.mes IN (1, 2)
      AND f.tiene_stock = true
    GROUP BY c.nivel2
    HAVING COUNT(DISTINCT CASE WHEN d.mes = 1 THEN f.producto_id END) >= 5
       AND COUNT(DISTINCT CASE WHEN d.mes = 2 THEN f.producto_id END) >= 5
)
SELECT 
    categoria,
    ROUND(precio_enero, 2) as precio_enero,
    ROUND(precio_febrero, 2) as precio_febrero,
    ROUND(precio_febrero - precio_enero, 2) as aumento_pesos,
    ROUND((precio_febrero - precio_enero) / precio_enero * 100, 2) as aumento_porcentaje,
    productos as productos_analizados
FROM variaciones
WHERE precio_febrero > precio_enero
ORDER BY aumento_porcentaje DESC
LIMIT 10;

-- ========================================
-- Query para Dashboard: Resumen ejecutivo
-- ========================================
SELECT 
    COUNT(DISTINCT c.nivel1) as categorias_principales,
    COUNT(DISTINCT c.nivel2) as subcategorias_totales,
    ROUND(AVG(f.precio_venta), 2) as precio_promedio_general,
    -- Inflación general
    ROUND(
        (AVG(CASE WHEN d.mes = 2 THEN f.precio_venta END) - 
         AVG(CASE WHEN d.mes = 1 THEN f.precio_venta END)) / 
         AVG(CASE WHEN d.mes = 1 THEN f.precio_venta END) * 100, 
    2) as inflacion_general_porcentaje,
    -- Categorías con aumentos
    COUNT(DISTINCT CASE 
        WHEN (AVG(CASE WHEN d.mes = 2 THEN f.precio_venta END) > 
              AVG(CASE WHEN d.mes = 1 THEN f.precio_venta END)) 
        THEN c.nivel2 
    END) as categorias_con_aumentos,
    -- Categorías estables
    COUNT(DISTINCT CASE 
        WHEN ABS(AVG(CASE WHEN d.mes = 2 THEN f.precio_venta END) - 
                 AVG(CASE WHEN d.mes = 1 THEN f.precio_venta END)) < 
                 AVG(CASE WHEN d.mes = 1 THEN f.precio_venta END) * 0.02
        THEN c.nivel2 
    END) as categorias_estables
FROM fact_precio_diario f
JOIN dim_categoria c ON f.categoria_id = c.categoria_id
JOIN dim_fecha d ON f.fecha_id = d.fecha_id
WHERE d.año = 2024 
  AND d.mes IN (1, 2)
  AND f.tiene_stock = true;
