# 📦 DIM_PRODUCTO

## ¿Qué es?
La tabla que describe los productos que vendemos. Información que no cambia frecuentemente.

## Estructura Simplificada

```sql
CREATE TABLE dim_producto (
    -- Identificador único
    producto_id         INT PRIMARY KEY,
    
    -- Información básica
    sku                 VARCHAR(50),       -- Código único del producto
    nombre              VARCHAR(200),      -- Nombre completo
    nombre_corto        VARCHAR(100),      -- Nombre para mostrar
    
    -- Clasificación
    marca               VARCHAR(100),      -- Ej: "La Costeña"
    categoria_id        INT,              -- Link a dim_categoria
    
    -- Características físicas
    tamaño              VARCHAR(50),       -- Ej: "5L", "1kg", "12 piezas"
    unidad_medida       VARCHAR(20),       -- Ej: "litro", "kilogramo", "pieza"
    
    -- Útil para análisis
    tipo_rotacion       VARCHAR(20),       -- "alta", "media", "baja"
    es_perecedero       BOOLEAN,          -- true/false
    requiere_frio       BOOLEAN           -- true/false
);
```

## ¿Por qué cada campo?

### 🔑 producto_id / sku
- **¿Por qué?** Identificación única, el SKU puede venir del proveedor
- **Uso:** Conectar con tablas de hechos

### 📝 nombre / nombre_corto
- **¿Por qué?** nombre completo para búsquedas, corto para reportes
- **Ejemplo:** 
  - Nombre: "Aceite de Oliva Extra Virgen La Española 5 Litros"
  - Corto: "Aceite Oliva EV 5L"

### 🏷️ marca
- **¿Por qué?** Análisis por marca, negociaciones
- **Pregunta 1:** "¿Cómo varían los precios de productos Nestlé?"

### 📏 tamaño / unidad_medida
- **¿Por qué?** Comparar precios justos (precio por litro, por kg)
- **Pregunta 2:** Solo comparar volatilidad entre productos del mismo tamaño

### 🔄 tipo_rotacion
- **¿Por qué?** Estrategias diferentes para productos de alta vs baja rotación
- **Pregunta 3:** Productos de alta rotación necesitan análisis más frecuente

### 🥶 es_perecedero / requiere_frio
- **¿Por qué?** Afecta estrategias de compra y urgencia
- **Pregunta 3:** Productos perecederos no se pueden comprar con mucha anticipación

## Ejemplo de Datos

| producto_id | sku | nombre | marca | tamaño | tipo_rotacion | es_perecedero |
|-------------|-----|---------|--------|---------|---------------|---------------|
| 101 | AC-OL-5L | Aceite Oliva EV 5L | La Española | 5L | alta | false |
| 102 | LE-ENT-1L | Leche Entera 1L | Lala | 1L | alta | true |
| 103 | DT-LQ-5L | Detergente Líquido 5L | Ariel | 5L | media | false |

## Manejo de Cambios (Simple)

Cuando cambia algo importante del producto:
1. **Opción Simple:** Actualizar el registro (perder historia)
2. **Opción Mejor:** Crear nuevo producto_id y marcar el anterior como descontinuado

```sql
-- Agregar campo para manejar productos descontinuados
ALTER TABLE dim_producto ADD COLUMN activo BOOLEAN DEFAULT true;
ALTER TABLE dim_producto ADD COLUMN fecha_actualizacion DATE;
```

## Query de Ejemplo

### Productos más vendidos por categoría
```sql
SELECT 
    p.marca,
    p.nombre_corto,
    p.tipo_rotacion,
    COUNT(DISTINCT f.fecha_id) as dias_con_datos,
    AVG(f.precio_venta) as precio_promedio
FROM dim_producto p
JOIN fact_precio_diario f ON p.producto_id = f.producto_id
WHERE p.activo = true
  AND p.tipo_rotacion = 'alta'
GROUP BY p.marca, p.nombre_corto, p.tipo_rotacion
ORDER BY dias_con_datos DESC;
```
