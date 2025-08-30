# 🏷️ DIM_CATEGORIA

## ¿Qué es?
La tabla que organiza los productos en categorías jerárquicas. Facilita análisis por tipo de producto.

## Estructura Simplificada

```sql
CREATE TABLE dim_categoria (
    -- Identificador único
    categoria_id        INT PRIMARY KEY,
    
    -- Jerarquía de categorías
    nivel1              VARCHAR(100),      -- "Alimentos"
    nivel2              VARCHAR(100),      -- "Aceites y Vinagres"
    nivel3              VARCHAR(100),      -- "Aceite de Oliva"
    
    -- Nombre completo para reportes
    nombre_completo     VARCHAR(300),      -- "Alimentos > Aceites > Aceite de Oliva"
    
    -- Características de la categoría
    es_perecedero       BOOLEAN,          -- ¿Productos perecederos?
    volatilidad_tipica  VARCHAR(20),      -- "baja", "media", "alta"
    margen_tipico       VARCHAR(20),      -- "bajo_5", "medio_10", "alto_20"
    
    -- Comportamiento de compra
    frecuencia_compra   VARCHAR(20),      -- "diaria", "semanal", "mensual"
    estacionalidad      VARCHAR(50)       -- "todo_año", "verano", "invierno", "fiestas"
);
```

## ¿Por qué cada campo?

### 🔑 categoria_id
- **¿Por qué?** Identificador único para joins
- **Uso:** Conectar productos con su categoría

### 📊 nivel1 / nivel2 / nivel3
- **¿Por qué?** Análisis a diferentes niveles de detalle
- **Pregunta 1:** "Variación de precios en Alimentos vs Limpieza"
- **Ejemplo jerarquía:**
  ```
  Alimentos (nivel1)
  └── Aceites y Vinagres (nivel2)
      └── Aceite de Oliva (nivel3)
  ```

### 📝 nombre_completo
- **¿Por qué?** Claridad en reportes
- **Uso:** Mostrar "Alimentos > Aceites > Aceite de Oliva"

### 🌡️ volatilidad_tipica
- **¿Por qué?** Expectativas por categoría
- **Pregunta 2:** Aceites = baja volatilidad, Frutas = alta volatilidad

### 💰 margen_tipico
- **¿Por qué?** Entender potencial de ahorro
- **Pregunta 5:** Categorías con márgenes altos = más oportunidad de ahorro

### 🔄 frecuencia_compra
- **¿Por qué?** Estrategias diferentes por frecuencia
- **Pregunta 3:** Productos diarios necesitan análisis más detallado

### 🌞 estacionalidad
- **¿Por qué?** Anticipar cambios de precio
- **Pregunta 3:** Helados más caros en verano

## Ejemplo de Datos

| categoria_id | nivel1 | nivel2 | nivel3 | volatilidad | frecuencia | estacionalidad |
|--------------|---------|---------|---------|-------------|------------|----------------|
| 1 | Alimentos | Aceites | Aceite Oliva | baja | mensual | todo_año |
| 2 | Alimentos | Lácteos | Leche | media | semanal | todo_año |
| 3 | Bebidas | Refrescos | Cola | baja | semanal | verano |
| 4 | Limpieza | Detergentes | Líquidos | baja | mensual | todo_año |

## Queries de Ejemplo

### Variación de precios por categoría nivel 1
```sql
-- ¿Qué categorías principales están subiendo más?
WITH precios_por_mes AS (
    SELECT 
        c.nivel1,
        d.mes,
        d.nombre_mes,
        AVG(f.precio_promedio_mercado) as precio_promedio_mes
    FROM fact_precio_diario f
    JOIN dim_categoria c ON f.categoria_id = c.categoria_id
    JOIN dim_fecha d ON f.fecha_id = d.fecha_id
    WHERE d.año = 2024
    GROUP BY c.nivel1, d.mes, d.nombre_mes
)
SELECT 
    nivel1,
    nombre_mes,
    precio_promedio_mes,
    LAG(precio_promedio_mes) OVER (PARTITION BY nivel1 ORDER BY mes) as precio_mes_anterior,
    ROUND(
        ((precio_promedio_mes - LAG(precio_promedio_mes) OVER (PARTITION BY nivel1 ORDER BY mes)) 
        / LAG(precio_promedio_mes) OVER (PARTITION BY nivel1 ORDER BY mes)) * 100, 
    2) as variacion_pct
FROM precios_por_mes
ORDER BY nivel1, mes;
```

### Categorías con mayor oportunidad de ahorro
```sql
-- ¿Dónde hay más diferencia entre proveedores?
SELECT 
    c.nivel2 as categoria,
    c.margen_tipico,
    COUNT(DISTINCT f.producto_id) as productos,
    AVG(f.precio_maximo_mercado - f.precio_minimo_mercado) as rango_precio_promedio,
    AVG((f.precio_maximo_mercado - f.precio_minimo_mercado) / f.precio_promedio_mercado * 100) as oportunidad_ahorro_pct
FROM fact_precio_diario f
JOIN dim_categoria c ON f.categoria_id = c.categoria_id
WHERE f.fecha_id >= 20240101
GROUP BY c.nivel2, c.margen_tipico
HAVING COUNT(DISTINCT f.producto_id) >= 10
ORDER BY oportunidad_ahorro_pct DESC;
```

### Análisis de estacionalidad
```sql
-- ¿Qué categorías son más caras en ciertas épocas?
SELECT 
    c.nivel2,
    c.estacionalidad,
    d.trimestre,
    AVG(f.precio_promedio_mercado) as precio_promedio_trimestre,
    RANK() OVER (PARTITION BY c.nivel2 ORDER BY AVG(f.precio_promedio_mercado) DESC) as ranking_precio
FROM fact_precio_diario f
JOIN dim_categoria c ON f.categoria_id = c.categoria_id
JOIN dim_fecha d ON f.fecha_id = d.fecha_id
WHERE c.estacionalidad != 'todo_año'
GROUP BY c.nivel2, c.estacionalidad, d.trimestre;
```

## 💡 Tips para Análisis

1. **Siempre considera la jerarquía**: Analiza primero nivel1, luego profundiza
2. **Volatilidad esperada**: No alarmes si frutas varían 20%, es normal
3. **Estacionalidad**: Planifica compras anticipando temporadas
4. **Márgenes**: Mayor margen = mayor potencial de negociación
