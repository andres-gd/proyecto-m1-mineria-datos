# 💰 FACT_COMPRAS_AHORRO

## ¿Qué es?
Una tabla que registra cada compra realizada y calcula cuánto ahorramos vs el mercado. Es la prueba del valor que generamos.

## Estructura de la Tabla

```sql
CREATE TABLE fact_compras_ahorro (
    -- Identificadores
    orden_id         VARCHAR(50),    -- ID único de la orden
    cliente_id       INT,            -- ¿Quién compró?
    
    -- Claves para conectar con dimensiones
    producto_id      INT,            -- ¿Qué compró?
    proveedor_id     INT,            -- ¿A quién le compró?
    fecha_id         INT,            -- ¿Cuándo compró?
    
    -- Detalles de la compra
    cantidad_comprada        DECIMAL(10,2),   -- ¿Cuánto compró?
    precio_unitario_pagado   DECIMAL(10,2),   -- ¿A qué precio?
    total_pagado            DECIMAL(10,2),   -- cantidad * precio
    
    -- Comparación con mercado
    precio_promedio_mercado  DECIMAL(10,2),   -- ¿Cuál era el precio promedio ese día?
    precio_maximo_mercado    DECIMAL(10,2),   -- ¿Cuál era el precio más caro?
    
    -- Ahorros calculados
    ahorro_vs_promedio      DECIMAL(10,2),   -- Lo que ahorramos vs promedio
    ahorro_vs_maximo        DECIMAL(10,2),   -- Lo que ahorramos vs más caro
    porcentaje_ahorro       DECIMAL(5,2),    -- % de ahorro
    
    PRIMARY KEY (orden_id, producto_id)
);
```

## ¿Por qué cada campo? ¿Cómo ayuda a responder las preguntas?

### 🆔 orden_id / cliente_id
- **¿Por qué?** Identificar cada transacción y quién la hizo
- **Pregunta 5:** Agrupar ahorros por cliente y período

### 🛒 cantidad_comprada / precio_unitario_pagado / total_pagado
- **¿Por qué?** Los datos básicos de cualquier compra
- **Pregunta 5:** Base para calcular ahorros totales

### 📊 precio_promedio_mercado
- **¿Por qué?** Para comparar contra el mercado
- **Pregunta 5:** Si pagamos menos que el promedio, hay ahorro

### 💵 ahorro_vs_promedio
- **¿Por qué?** El ahorro real en pesos
- **Fórmula:** (precio_promedio_mercado - precio_unitario_pagado) * cantidad_comprada
- **Pregunta 5:** Sumar todos los ahorros del mes

### 📈 ahorro_vs_maximo
- **¿Por qué?** El máximo ahorro posible
- **Fórmula:** (precio_maximo_mercado - precio_unitario_pagado) * cantidad_comprada
- **Marketing:** "Ahorraste hasta $X comprando con nosotros"

### 📊 porcentaje_ahorro
- **¿Por qué?** Más fácil de entender que montos absolutos
- **Fórmula:** (ahorro_vs_promedio / (precio_promedio_mercado * cantidad)) * 100
- **Pregunta 5:** "Promedio de ahorro: 12%"

## Ejemplo de Datos

| orden_id | producto_id | cantidad | precio_pagado | precio_promedio | ahorro_vs_promedio | porcentaje_ahorro |
|----------|-------------|----------|---------------|-----------------|-------------------|-------------------|
| ORD-001 | 101 | 10 | 385.50 | 400.00 | 145.00 | 3.6% |
| ORD-001 | 102 | 5 | 125.00 | 130.00 | 25.00 | 3.8% |
| ORD-002 | 101 | 20 | 380.00 | 400.00 | 400.00 | 5.0% |

## Queries de Ejemplo

### ¿Cuánto ahorramos a nuestros clientes este mes?
```sql
SELECT 
    COUNT(DISTINCT cliente_id) as clientes_activos,
    COUNT(DISTINCT orden_id) as total_ordenes,
    SUM(total_pagado) as ventas_totales,
    SUM(ahorro_vs_promedio) as ahorro_total,
    AVG(porcentaje_ahorro) as porcentaje_ahorro_promedio,
    SUM(ahorro_vs_promedio) / COUNT(DISTINCT cliente_id) as ahorro_por_cliente
FROM fact_compras_ahorro
WHERE fecha_id BETWEEN 20240101 AND 20240131;
```

### ¿Qué clientes están ahorrando más?
```sql
SELECT 
    cliente_id,
    COUNT(DISTINCT orden_id) as numero_ordenes,
    SUM(total_pagado) as total_gastado,
    SUM(ahorro_vs_promedio) as total_ahorrado,
    AVG(porcentaje_ahorro) as porcentaje_ahorro_promedio
FROM fact_compras_ahorro
WHERE fecha_id BETWEEN 20240101 AND 20240131
GROUP BY cliente_id
ORDER BY total_ahorrado DESC
LIMIT 10;
```

## 💡 Nota Importante

Esta tabla se llena DESPUÉS de cada compra, no antes. Los precios del mercado se toman del mismo día de la compra para una comparación justa.
