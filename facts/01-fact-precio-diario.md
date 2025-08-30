# 📊 FACT_PRECIO_DIARIO

## ¿Qué es?
Una tabla que captura el precio de cada producto, de cada proveedor, cada día. Es nuestra fuente principal para análisis de tendencias y comparaciones.

## Estructura de la Tabla

```sql
CREATE TABLE fact_precio_diario (
    -- Claves para conectar con dimensiones
    producto_id      INT,      -- ¿Qué producto?
    proveedor_id     INT,      -- ¿Quién lo vende?
    fecha_id         INT,      -- ¿Cuándo?
    categoria_id     INT,      -- ¿De qué tipo?
    
    -- Métricas de precio
    precio_venta              DECIMAL(10,2),   -- El precio real de venta hoy
    precio_promedio_mercado   DECIMAL(10,2),   -- Promedio de todos los proveedores hoy
    precio_minimo_mercado     DECIMAL(10,2),   -- El más barato del mercado hoy
    precio_maximo_mercado     DECIMAL(10,2),   -- El más caro del mercado hoy
    
    -- Indicadores útiles
    tiene_stock              BOOLEAN,          -- ¿Está disponible?
    es_precio_mas_bajo      BOOLEAN,          -- ¿Es el más barato del mercado?
    
    -- Clave primaria compuesta
    PRIMARY KEY (producto_id, proveedor_id, fecha_id)
);
```

## ¿Por qué cada campo? ¿Cómo ayuda a responder las preguntas?

### 🔑 Claves (producto_id, proveedor_id, fecha_id, categoria_id)
- **¿Por qué?** Necesitamos identificar únicamente cada combinación
- **Ayuda con:** TODAS las preguntas - son la base para agrupar y filtrar

### 💰 precio_venta
- **¿Por qué?** Es el dato más importante - el precio real
- **Pregunta 1:** Calcular promedio por categoría
- **Pregunta 2:** Medir volatilidad (max - min)
- **Pregunta 4:** Comparar precios entre proveedores

### 📊 precio_promedio_mercado
- **¿Por qué?** Para saber si un precio es bueno o malo
- **Pregunta 4:** Identificar proveedores caros/baratos
- **Pregunta 5:** Calcular ahorros vs promedio

### 📉 precio_minimo_mercado / 📈 precio_maximo_mercado
- **¿Por qué?** Para entender el rango de precios del día
- **Pregunta 2:** Medir volatilidad del mercado
- **Pregunta 3:** Identificar oportunidades
- **Pregunta 5:** Calcular máximo ahorro posible

### ✅ tiene_stock
- **¿Por qué?** Un buen precio no sirve si no hay stock
- **Pregunta 3:** Solo recomendar momentos con disponibilidad
- **Pregunta 4:** Penalizar proveedores sin stock frecuente

### 🏆 es_precio_mas_bajo
- **¿Por qué?** Identificación rápida del mejor precio
- **Pregunta 4:** Contar cuántas veces cada proveedor es el más barato
- **Pregunta 5:** Validar que compramos al mejor precio

## Ejemplo de Datos

| producto_id | proveedor_id | fecha_id | precio_venta | precio_promedio | tiene_stock | es_precio_mas_bajo |
|-------------|--------------|----------|--------------|-----------------|-------------|-------------------|
| 101 | 201 | 20240115 | 385.50 | 400.00 | true | true |
| 101 | 202 | 20240115 | 412.00 | 400.00 | true | false |
| 101 | 203 | 20240115 | 402.50 | 400.00 | false | false |

## Queries de Ejemplo

### ¿Cuánto varió el precio promedio esta semana?
```sql
SELECT 
    f.categoria_id,
    d.nombre_categoria,
    AVG(CASE WHEN fecha_id = 20240115 THEN precio_venta END) as precio_hoy,
    AVG(CASE WHEN fecha_id = 20240108 THEN precio_venta END) as precio_semana_pasada,
    ((AVG(CASE WHEN fecha_id = 20240115 THEN precio_venta END) - 
      AVG(CASE WHEN fecha_id = 20240108 THEN precio_venta END)) / 
      AVG(CASE WHEN fecha_id = 20240108 THEN precio_venta END) * 100) as variacion_pct
FROM fact_precio_diario f
JOIN dim_categoria d ON f.categoria_id = d.categoria_id
WHERE fecha_id IN (20240115, 20240108)
GROUP BY f.categoria_id, d.nombre_categoria;
```
