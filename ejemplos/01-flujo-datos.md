# 🔄 Flujo de Datos - Ejemplo Paso a Paso

## Escenario: Precio del Aceite de Oliva

Vamos a seguir el viaje de los datos desde que se capturan hasta que generan valor para el cliente.

## 1️⃣ Captura de Datos (Sources → Bronze)

### Día 1: Lunes 15 de Enero 2024, 10:00 AM

**Fuente 1: API de Costco Business**
```json
{
  "timestamp": "2024-01-15T10:00:00Z",
  "products": [{
    "sku": "CB-12345",
    "name": "Aceite de Oliva Extra Virgen La Española 5L",
    "price": 385.50,
    "stock": true,
    "category": "Grocery/Oils"
  }]
}
```

**Fuente 2: Web Scraping Restaurant Depot**
```json
{
  "timestamp": "2024-01-15T10:05:00Z",
  "scraped_data": {
    "product": "ACEITE OLIVA EV 5L ESPAÑOLA",
    "price": "$412.00 MXN",
    "availability": "In Stock"
  }
}
```

**Almacenamiento Bronze (S3)**
```
s3://rappi-b2b-bronze/precios/2024/01/15/
├── costco_10_00_00.json
└── restaurant_depot_10_05_00.json
```

## 2️⃣ Limpieza y Normalización (Bronze → Silver)

### Proceso ETL con Glue

**Transformaciones aplicadas:**
1. Normalizar nombres de productos
2. Convertir precios a decimal
3. Mapear categorías
4. Asignar IDs únicos

**Resultado Silver:**
```sql
-- Tabla: silver_precios_dia
INSERT INTO silver_precios_dia VALUES
(101, 201, '2024-01-15', 385.50, true),  -- Aceite en Costco
(101, 202, '2024-01-15', 412.00, true);  -- Aceite en Restaurant Depot
```

## 3️⃣ Cálculos y Agregaciones (Silver → Gold)

### Población de Fact Tables

**FACT_PRECIO_DIARIO:**
```sql
INSERT INTO fact_precio_diario VALUES (
    producto_id: 101,
    proveedor_id: 201,
    fecha_id: 20240115,
    categoria_id: 1,
    precio_venta: 385.50,
    precio_promedio_mercado: 398.75,  -- (385.50 + 412.00) / 2
    precio_minimo_mercado: 385.50,
    precio_maximo_mercado: 412.00,
    tiene_stock: true,
    es_precio_mas_bajo: true
);
```

## 4️⃣ Cliente Hace una Compra

### Día 2: Martes 16 de Enero, 2:00 PM

**Orden de compra:**
- Cliente: Restaurante El Buen Sabor (ID: 501)
- Producto: Aceite de Oliva 5L
- Cantidad: 10 unidades
- Proveedor elegido: Costco (mejor precio)

**Registro en FACT_COMPRAS_AHORRO:**
```sql
INSERT INTO fact_compras_ahorro VALUES (
    orden_id: 'ORD-2024-0001',
    cliente_id: 501,
    producto_id: 101,
    proveedor_id: 201,
    fecha_id: 20240116,
    cantidad_comprada: 10,
    precio_unitario_pagado: 385.50,
    total_pagado: 3855.00,
    precio_promedio_mercado: 398.75,
    precio_maximo_mercado: 412.00,
    ahorro_vs_promedio: 132.50,      -- (398.75 - 385.50) * 10
    ahorro_vs_maximo: 265.00,         -- (412.00 - 385.50) * 10
    porcentaje_ahorro: 3.3            -- 132.50 / (398.75 * 10) * 100
);
```

## 5️⃣ Generación de Insights

### Query 1: ¿Cuánto varió el precio?
```sql
SELECT 
    precio_venta as precio_hoy,
    LAG(precio_venta) OVER (ORDER BY fecha_id) as precio_ayer,
    ((precio_venta - LAG(precio_venta)) / LAG(precio_venta)) * 100 as variacion
FROM fact_precio_diario
WHERE producto_id = 101 AND proveedor_id = 201;

-- Resultado: +2.5% vs día anterior
```

### Query 2: ¿Quién ofrece el mejor precio?
```sql
SELECT 
    p.nombre,
    f.precio_venta,
    CASE WHEN f.es_precio_mas_bajo THEN '🏆' ELSE '' END as mejor
FROM fact_precio_diario f
JOIN dim_proveedor p ON f.proveedor_id = p.proveedor_id
WHERE producto_id = 101 AND fecha_id = 20240115;

-- Resultado:
-- Costco Business    | 385.50 | 🏆
-- Restaurant Depot   | 412.00 |
```

### Query 3: ¿Cuánto ahorramos al cliente?
```sql
SELECT 
    SUM(ahorro_vs_promedio) as ahorro_total,
    AVG(porcentaje_ahorro) as ahorro_promedio_pct
FROM fact_compras_ahorro
WHERE fecha_id = 20240116;

-- Resultado: $132.50 ahorrados (3.3%)
```

## 6️⃣ Dashboard Ejecutivo

### Vista Final para Stakeholders:

```
📊 RESUMEN DEL DÍA - 16 Enero 2024
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💰 Ahorro Total Generado: $2,547.50
📦 Órdenes Procesadas: 45
👥 Clientes Activos: 28
📈 Ahorro Promedio: 4.2%

TOP CATEGORÍAS POR AHORRO:
1. Aceites y Vinagres: $856.00 (5.1%)
2. Lácteos: $642.30 (3.8%)
3. Carnes: $1,049.20 (4.5%)

MEJOR PROVEEDOR HOY:
🏆 Costco Business
   - 67% de productos con mejor precio
   - Índice de precio: 0.96 (4% bajo mercado)
```

## 🔑 Puntos Clave del Flujo

1. **Velocidad**: De la captura al insight en < 1 hora
2. **Calidad**: Datos limpios y normalizados
3. **Valor**: Ahorro cuantificable para clientes
4. **Escalabilidad**: Mismo proceso para 100 o 100,000 productos

## 💡 Lecciones Aprendidas

- La clave está en la **normalización** correcta en Silver
- Los **pre-cálculos** en Gold aceleran queries
- Las **dimensiones simples** facilitan el análisis
- El **valor del ahorro** debe ser claro y medible
