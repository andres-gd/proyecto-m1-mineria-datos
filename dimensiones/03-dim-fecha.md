# 📅 DIM_FECHA

## ¿Qué es?
La tabla calendario que nos permite analizar por tiempo. Pre-poblada con todos los días del año.

## Estructura Simplificada

```sql
CREATE TABLE dim_fecha (
    -- Identificador único
    fecha_id            INT PRIMARY KEY,    -- Formato: YYYYMMDD (20240115)
    
    -- La fecha real
    fecha               DATE,               -- 2024-01-15
    
    -- Partes de la fecha
    año                 INT,                -- 2024
    mes                 INT,                -- 1
    dia                 INT,                -- 15
    
    -- Nombres útiles
    nombre_mes          VARCHAR(20),        -- "Enero"
    nombre_dia_semana   VARCHAR(20),        -- "Lunes"
    
    -- Agrupaciones
    trimestre           INT,                -- 1, 2, 3, 4
    semana_del_año      INT,                -- 1-52
    
    -- Indicadores de negocio
    es_fin_semana       BOOLEAN,           -- Sábado o Domingo
    es_dia_festivo      BOOLEAN,           -- Días festivos México
    es_quincena         BOOLEAN,           -- Día 15 o 30/31
    es_inicio_mes       BOOLEAN,           -- Primeros 5 días
    es_fin_mes          BOOLEAN,           -- Últimos 5 días
    
    -- Período de compra B2B
    periodo_compra      VARCHAR(20)         -- "inicio_mes", "quincena", "fin_mes"
);
```

## ¿Por qué cada campo?

### 🔑 fecha_id
- **¿Por qué?** Joins más rápidos con enteros que con fechas
- **Formato:** 20240115 es más fácil que '2024-01-15'

### 📅 año / mes / dia
- **¿Por qué?** Agrupar fácilmente por período
- **Pregunta 1:** "Variación de precios por mes"

### 📝 nombre_mes / nombre_dia_semana
- **¿Por qué?** Reportes más legibles
- **Pregunta 3:** "Los martes suelen tener mejores precios"

### 🎯 es_quincena
- **¿Por qué?** Muchas empresas compran en quincena
- **Pregunta 3:** "Evitar comprar el día 15 (alta demanda)"

### 📈 es_inicio_mes / es_fin_mes
- **¿Por qué?** Patrones de compra empresarial
- **Pregunta 3:** "Inicio de mes = presupuestos frescos = más demanda"

### 🏢 periodo_compra
- **¿Por qué?** Segmentar análisis por momento del mes
- **Valores:**
  - "inicio_mes": Días 1-10
  - "quincena": Días 14-16
  - "fin_mes": Últimos 5 días
  - "regular": Resto de días

## Ejemplo de Datos

| fecha_id | fecha | dia | nombre_dia | es_quincena | periodo_compra |
|----------|--------|-----|-----------|-------------|----------------|
| 20240115 | 2024-01-15 | 15 | Lunes | true | quincena |
| 20240116 | 2024-01-16 | 16 | Martes | false | regular |
| 20240131 | 2024-01-31 | 31 | Miércoles | true | fin_mes |

## Script para Poblar la Tabla

```sql
-- Llenar con fechas del 2024
INSERT INTO dim_fecha
SELECT 
    TO_NUMBER(TO_CHAR(fecha, 'YYYYMMDD')) as fecha_id,
    fecha,
    EXTRACT(YEAR FROM fecha) as año,
    EXTRACT(MONTH FROM fecha) as mes,
    EXTRACT(DAY FROM fecha) as dia,
    TO_CHAR(fecha, 'Month') as nombre_mes,
    TO_CHAR(fecha, 'Day') as nombre_dia_semana,
    EXTRACT(QUARTER FROM fecha) as trimestre,
    EXTRACT(WEEK FROM fecha) as semana_del_año,
    CASE WHEN EXTRACT(DOW FROM fecha) IN (0,6) THEN true ELSE false END as es_fin_semana,
    false as es_dia_festivo,  -- Actualizar manualmente
    CASE WHEN EXTRACT(DAY FROM fecha) IN (15, 30, 31) THEN true ELSE false END as es_quincena,
    CASE WHEN EXTRACT(DAY FROM fecha) <= 5 THEN true ELSE false END as es_inicio_mes,
    CASE WHEN EXTRACT(DAY FROM fecha) >= 26 THEN true ELSE false END as es_fin_mes,
    CASE 
        WHEN EXTRACT(DAY FROM fecha) <= 10 THEN 'inicio_mes'
        WHEN EXTRACT(DAY FROM fecha) BETWEEN 14 AND 16 THEN 'quincena'
        WHEN EXTRACT(DAY FROM fecha) >= 26 THEN 'fin_mes'
        ELSE 'regular'
    END as periodo_compra
FROM generate_series('2024-01-01'::date, '2024-12-31'::date, '1 day'::interval) as fecha;
```

## Queries de Ejemplo

### ¿Cuándo es mejor comprar?
```sql
-- Precio promedio por período del mes
SELECT 
    periodo_compra,
    COUNT(DISTINCT fecha_id) as dias_analizados,
    AVG(precio_promedio_mercado) as precio_promedio,
    MIN(precio_promedio_mercado) as mejor_precio,
    RANK() OVER (ORDER BY AVG(precio_promedio_mercado)) as ranking_precio
FROM fact_precio_diario f
JOIN dim_fecha d ON f.fecha_id = d.fecha_id
WHERE d.año = 2024
GROUP BY periodo_compra
ORDER BY precio_promedio;
```

### Tendencia de precios por día de la semana
```sql
SELECT 
    nombre_dia_semana,
    AVG(precio_venta) as precio_promedio,
    COUNT(*) as muestras,
    CASE 
        WHEN AVG(precio_venta) = MIN(AVG(precio_venta)) OVER () THEN '🏆 Mejor día'
        WHEN AVG(precio_venta) = MAX(AVG(precio_venta)) OVER () THEN '❌ Peor día'
        ELSE '➖ Regular'
    END as recomendacion
FROM fact_precio_diario f
JOIN dim_fecha d ON f.fecha_id = d.fecha_id
WHERE f.categoria_id = 1  -- Aceites
GROUP BY nombre_dia_semana
ORDER BY precio_promedio;
```

## 💡 Insights Típicos

- 📈 **Quincenas:** Precios suben 5-10% por alta demanda
- 📉 **Inicio de mes:** Buenos precios (días 5-10)
- 🏢 **Martes-Jueves:** Mejores días para comprar
- 🚫 **Lunes:** Evitar (reabastecimiento = precios altos)
