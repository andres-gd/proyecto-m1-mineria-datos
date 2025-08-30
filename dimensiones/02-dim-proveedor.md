# 🏪 DIM_PROVEEDOR

## ¿Qué es?
La tabla que describe a los proveedores/vendedores. Información sobre quién vende los productos.

## Estructura Simplificada

```sql
CREATE TABLE dim_proveedor (
    -- Identificador único
    proveedor_id        INT PRIMARY KEY,
    
    -- Información básica
    nombre              VARCHAR(200),      -- Nombre comercial
    tipo                VARCHAR(50),       -- "mayorista", "distribuidor", "fabricante"
    
    -- Ubicación
    ciudad              VARCHAR(100),      -- Ciudad principal
    zona_cobertura      VARCHAR(100),      -- "CDMX", "Nacional", "Centro"
    
    -- Características del servicio
    tiene_api           BOOLEAN,          -- ¿Integración automática?
    tiempo_entrega_dias INT,              -- Días promedio de entrega
    pedido_minimo       DECIMAL(10,2),    -- Monto mínimo de compra
    
    -- Evaluación
    calificacion        DECIMAL(3,2),     -- 1.0 a 5.0
    nivel_precio        VARCHAR(20),       -- "economico", "medio", "premium"
    
    -- Estado
    activo              BOOLEAN,          -- ¿Está activo?
    fecha_alta          DATE              -- ¿Cuándo empezamos a trabajar?
);
```

## ¿Por qué cada campo?

### 🆔 proveedor_id / nombre
- **¿Por qué?** Identificación básica
- **Uso:** "Costco Business" es más claro que "proveedor_123"

### 🏢 tipo
- **¿Por qué?** Estrategias diferentes por tipo
- **Pregunta 4:** Comparar mayoristas vs distribuidores

### 📍 ciudad / zona_cobertura
- **¿Por qué?** No todos entregan en todas partes
- **Pregunta 3:** Mejores momentos pueden variar por zona

### ⚡ tiene_api
- **¿Por qué?** Datos más frescos y confiables con API
- **Impacto:** Proveedores con API = precios actualizados cada hora

### 📦 tiempo_entrega_dias / pedido_minimo
- **¿Por qué?** Restricciones operativas importantes
- **Pregunta 3:** No sirve buen precio si tarda 10 días

### ⭐ calificacion
- **¿Por qué?** No solo importa el precio
- **Pregunta 4:** Balance entre precio y servicio

### 💰 nivel_precio
- **¿Por qué?** Clasificación rápida
- **Pregunta 4:** Saber qué esperar de cada proveedor

## Ejemplo de Datos

| proveedor_id | nombre | tipo | ciudad | tiempo_entrega | calificacion | nivel_precio |
|--------------|---------|------|---------|----------------|--------------|--------------|
| 201 | Costco Business | mayorista | CDMX | 1 | 4.8 | economico |
| 202 | Restaurant Depot | mayorista | CDMX | 2 | 4.5 | economico |
| 203 | Distribuidora Elite | distribuidor | CDMX | 1 | 4.2 | premium |

## Queries de Ejemplo

### Ranking de proveedores por competitividad
```sql
-- ¿Quién ofrece mejores precios consistentemente?
SELECT 
    p.nombre,
    p.tipo,
    p.nivel_precio,
    COUNT(DISTINCT f.producto_id) as productos_ofrecidos,
    AVG(CASE WHEN f.es_precio_mas_bajo THEN 1 ELSE 0 END) * 100 as pct_mejor_precio,
    AVG(f.precio_venta / f.precio_promedio_mercado) as indice_precio,
    p.calificacion
FROM dim_proveedor p
JOIN fact_precio_diario f ON p.proveedor_id = f.proveedor_id
WHERE p.activo = true
  AND f.fecha_id >= 20240101  -- Último mes
GROUP BY p.proveedor_id, p.nombre, p.tipo, p.nivel_precio, p.calificacion
HAVING COUNT(DISTINCT f.producto_id) >= 50  -- Solo proveedores con catálogo amplio
ORDER BY pct_mejor_precio DESC;
```

### Proveedores por zona y tiempo de entrega
```sql
-- ¿Quién entrega rápido en mi zona?
SELECT 
    zona_cobertura,
    nombre,
    tiempo_entrega_dias,
    calificacion,
    nivel_precio,
    CASE 
        WHEN tiempo_entrega_dias = 1 THEN '🚀 Express'
        WHEN tiempo_entrega_dias <= 3 THEN '✅ Rápido'
        ELSE '🐌 Lento'
    END as velocidad_entrega
FROM dim_proveedor
WHERE activo = true
  AND zona_cobertura IN ('CDMX', 'Nacional')
ORDER BY tiempo_entrega_dias, calificacion DESC;
```

## 💡 Tip para Análisis

Siempre considera el balance entre:
- 💰 Precio (nivel_precio, índice de precios)
- ⚡ Velocidad (tiempo_entrega_dias)
- ⭐ Confiabilidad (calificacion)
- 📦 Disponibilidad (cantidad de productos)
