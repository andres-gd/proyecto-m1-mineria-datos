-- ========================================
-- PREGUNTA 2: ¿Qué productos tienen mayor volatilidad de precio?
-- ========================================
-- Objetivo: Identificar productos con precios inestables para gestionar riesgos
-- ========================================

-- Query Principal: Top 20 productos más volátiles
WITH volatilidad_productos AS (
    -- Paso 1: Calcular métricas de volatilidad por producto
    SELECT 
        p.producto_id,
        p.nombre as producto,
        p.marca,
        p.tamaño,
        c.nivel2 as categoria,
        COUNT(DISTINCT f.fecha_id) as dias_con_datos,
        COUNT(DISTINCT f.proveedor_id) as num_proveedores,
        -- Métricas de precio
        MIN(f.precio_venta) as precio_minimo,
        MAX(f.precio_venta) as precio_maximo,
        AVG(f.precio_venta) as precio_promedio,
        STDDEV(f.precio_venta) as desviacion_estandar,
        -- Volatilidad absoluta y relativa
        MAX(f.precio_venta) - MIN(f.precio_venta) as rango_precio,
        ROUND((MAX(f.precio_venta) - MIN(f.precio_venta)) / AVG(f.precio_venta) * 100, 2) as volatilidad_relativa,
        -- Coeficiente de variación (medida más justa)
        ROUND(STDDEV(f.precio_venta) / AVG(f.precio_venta) * 100, 2) as coeficiente_variacion
    FROM fact_precio_diario f
    JOIN dim_producto p ON f.producto_id = p.producto_id
    JOIN dim_categoria c ON f.categoria_id = c.categoria_id
    JOIN dim_fecha d ON f.fecha_id = d.fecha_id
    WHERE d.fecha >= CURRENT_DATE - INTERVAL '30 days'  -- Últimos 30 días
      AND f.tiene_stock = true
    GROUP BY p.producto_id, p.nombre, p.marca, p.tamaño, c.nivel2
    HAVING COUNT(DISTINCT f.fecha_id) >= 15  -- Mínimo 15 días de datos
)
SELECT 
    producto,
    marca,
    tamaño,
    categoria,
    dias_con_datos,
    num_proveedores,
    ROUND(precio_minimo, 2) as precio_minimo,
    ROUND(precio_maximo, 2) as precio_maximo,
    ROUND(precio_promedio, 2) as precio_promedio,
    ROUND(rango_precio, 2) as rango_precio,
    coeficiente_variacion as volatilidad_cv,
    -- Clasificación de volatilidad
    CASE 
        WHEN coeficiente_variacion > 30 THEN '🔴 MUY ALTA'
        WHEN coeficiente_variacion > 20 THEN '🟠 ALTA'
        WHEN coeficiente_variacion > 10 THEN '🟡 MODERADA'
        WHEN coeficiente_variacion > 5 THEN '🟢 BAJA'
        ELSE '💚 MUY BAJA'
    END as nivel_volatilidad,
    -- Riesgo para compras
    CASE 
        WHEN coeficiente_variacion > 20 THEN 'Alto riesgo - Comprar con precaución'
        WHEN coeficiente_variacion > 10 THEN 'Riesgo moderado - Monitorear precios'
        ELSE 'Bajo riesgo - Precio estable'
    END as recomendacion
FROM volatilidad_productos
ORDER BY coeficiente_variacion DESC
LIMIT 20;

-- ========================================
-- Query: Volatilidad por categoría
-- ========================================
WITH volatilidad_categorias AS (
    SELECT 
        c.nivel1 as categoria_principal,
        c.nivel2 as subcategoria,
        c.volatilidad_tipica as volatilidad_esperada,
        COUNT(DISTINCT f.producto_id) as productos,
        -- Volatilidad promedio de la categoría
        AVG(
            (SELECT STDDEV(f2.precio_venta) / AVG(f2.precio_venta) * 100
             FROM fact_precio_diario f2
             WHERE f2.producto_id = f.producto_id
               AND f2.fecha_id >= 20240101)
        ) as volatilidad_promedio_real,
        -- Productos con alta volatilidad en la categoría
        COUNT(DISTINCT CASE 
            WHEN (SELECT STDDEV(f2.precio_venta) / AVG(f2.precio_venta) * 100
                  FROM fact_precio_diario f2
                  WHERE f2.producto_id = f.producto_id
                    AND f2.fecha_id >= 20240101) > 20 
            THEN f.producto_id 
        END) as productos_alta_volatilidad
    FROM fact_precio_diario f
    JOIN dim_categoria c ON f.categoria_id = c.categoria_id
    WHERE f.fecha_id >= 20240101
    GROUP BY c.nivel1, c.nivel2, c.volatilidad_tipica
)
SELECT 
    categoria_principal,
    subcategoria,
    volatilidad_esperada,
    productos as total_productos,
    ROUND(volatilidad_promedio_real, 2) as volatilidad_real,
    productos_alta_volatilidad,
    ROUND(productos_alta_volatilidad::FLOAT / productos * 100, 2) as pct_productos_volatiles,
    -- Comparación con lo esperado
    CASE 
        WHEN volatilidad_esperada = 'alta' AND volatilidad_promedio_real > 20 THEN '✅ Como esperado'
        WHEN volatilidad_esperada = 'media' AND volatilidad_promedio_real BETWEEN 10 AND 20 THEN '✅ Como esperado'
        WHEN volatilidad_esperada = 'baja' AND volatilidad_promedio_real < 10 THEN '✅ Como esperado'
        ELSE '⚠️ Fuera de lo esperado'
    END as validacion
FROM volatilidad_categorias
ORDER BY volatilidad_promedio_real DESC;

-- ========================================
-- Query: Histórico de volatilidad (tendencia)
-- ========================================
WITH volatilidad_temporal AS (
    SELECT 
        p.producto_id,
        p.nombre as producto,
        d.semana_del_año,
        MIN(f.precio_venta) as precio_min_semana,
        MAX(f.precio_venta) as precio_max_semana,
        AVG(f.precio_venta) as precio_avg_semana,
        (MAX(f.precio_venta) - MIN(f.precio_venta)) / AVG(f.precio_venta) * 100 as volatilidad_semana
    FROM fact_precio_diario f
    JOIN dim_producto p ON f.producto_id = p.producto_id
    JOIN dim_fecha d ON f.fecha_id = d.fecha_id
    WHERE d.año = 2024
      AND p.producto_id IN (
          -- Top 5 productos más volátiles
          SELECT producto_id 
          FROM fact_precio_diario 
          GROUP BY producto_id 
          HAVING STDDEV(precio_venta) / AVG(precio_venta) > 0.15
          ORDER BY STDDEV(precio_venta) / AVG(precio_venta) DESC 
          LIMIT 5
      )
    GROUP BY p.producto_id, p.nombre, d.semana_del_año
)
SELECT 
    producto,
    semana_del_año,
    ROUND(precio_avg_semana, 2) as precio_promedio,
    ROUND(volatilidad_semana, 2) as volatilidad_pct,
    -- Tendencia de volatilidad
    CASE 
        WHEN volatilidad_semana > LAG(volatilidad_semana) OVER (PARTITION BY producto ORDER BY semana_del_año) THEN '📈 Aumentando'
        WHEN volatilidad_semana < LAG(volatilidad_semana) OVER (PARTITION BY producto ORDER BY semana_del_año) THEN '📉 Disminuyendo'
        ELSE '→ Estable'
    END as tendencia_volatilidad
FROM volatilidad_temporal
ORDER BY producto, semana_del_año;

-- ========================================
-- Query para alertas: Productos con cambios bruscos HOY
-- ========================================
SELECT 
    p.nombre as producto,
    p.marca,
    pr.nombre as proveedor,
    f.precio_venta as precio_hoy,
    LAG(f.precio_venta) OVER (PARTITION BY f.producto_id, f.proveedor_id ORDER BY f.fecha_id) as precio_ayer,
    ROUND(
        ((f.precio_venta - LAG(f.precio_venta) OVER (PARTITION BY f.producto_id, f.proveedor_id ORDER BY f.fecha_id)) / 
         LAG(f.precio_venta) OVER (PARTITION BY f.producto_id, f.proveedor_id ORDER BY f.fecha_id)) * 100, 
    2) as cambio_porcentaje,
    CASE 
        WHEN ABS((f.precio_venta - LAG(f.precio_venta) OVER (PARTITION BY f.producto_id, f.proveedor_id ORDER BY f.fecha_id)) / 
                 LAG(f.precio_venta) OVER (PARTITION BY f.producto_id, f.proveedor_id ORDER BY f.fecha_id)) > 0.20 THEN '🚨 ALERTA CRÍTICA'
        WHEN ABS((f.precio_venta - LAG(f.precio_venta) OVER (PARTITION BY f.producto_id, f.proveedor_id ORDER BY f.fecha_id)) / 
                 LAG(f.precio_venta) OVER (PARTITION BY f.producto_id, f.proveedor_id ORDER BY f.fecha_id)) > 0.10 THEN '⚠️ ALERTA ALTA'
        ELSE '✅ Normal'
    END as nivel_alerta
FROM fact_precio_diario f
JOIN dim_producto p ON f.producto_id = p.producto_id
JOIN dim_proveedor pr ON f.proveedor_id = pr.proveedor_id
WHERE f.fecha_id = TO_NUMBER(TO_CHAR(CURRENT_DATE, 'YYYYMMDD'))
  AND ABS((f.precio_venta - LAG(f.precio_venta) OVER (PARTITION BY f.producto_id, f.proveedor_id ORDER BY f.fecha_id)) / 
          LAG(f.precio_venta) OVER (PARTITION BY f.producto_id, f.proveedor_id ORDER BY f.fecha_id)) > 0.10
ORDER BY cambio_porcentaje DESC;
