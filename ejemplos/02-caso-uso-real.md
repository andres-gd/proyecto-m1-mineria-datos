# 💼 Caso de Uso Real - Restaurante "El Buen Sabor"

## 🏢 Contexto del Cliente

**Negocio**: Restaurante El Buen Sabor
- Tipo: Restaurante familiar mexicano
- Ubicación: Roma Norte, CDMX
- Tamaño: 50 mesas, 15 empleados
- Compras mensuales: ~$150,000 MXN

## 📅 Situación: Planificación de Compras para Febrero 2024

El gerente de compras, Carlos, necesita optimizar el presupuesto y quiere usar nuestros insights.

## 1️⃣ Pregunta: ¿Qué productos están subiendo de precio?

### Consulta de Carlos:
"Necesito saber qué insumos están subiendo para ajustar mi presupuesto"

### Query Ejecutada:
```sql
SELECT 
    c.nivel2 as categoria,
    AVG(CASE WHEN d.mes = 1 THEN f.precio_venta END) as precio_enero,
    AVG(CASE WHEN d.mes = 2 THEN f.precio_venta END) as precio_febrero,
    ROUND(((AVG(CASE WHEN d.mes = 2 THEN f.precio_venta END) - 
            AVG(CASE WHEN d.mes = 1 THEN f.precio_venta END)) / 
            AVG(CASE WHEN d.mes = 1 THEN f.precio_venta END)) * 100, 2) as variacion_pct
FROM fact_precio_diario f
JOIN dim_categoria c ON f.categoria_id = c.categoria_id
JOIN dim_fecha d ON f.fecha_id = d.fecha_id
WHERE c.nivel1 = 'Alimentos'
  AND d.año = 2024
  AND d.mes IN (1, 2)
GROUP BY c.nivel2
ORDER BY variacion_pct DESC;
```

### Resultado para Carlos:
```
┌─────────────────────┬───────────────┬────────────────┬──────────────┐
│ Categoría           │ Precio Enero  │ Precio Febrero │ Variación %  │
├─────────────────────┼───────────────┼────────────────┼──────────────┤
│ Aguacate            │ $65.00        │ $85.00         │ +30.8% 🔴    │
│ Limón               │ $28.00        │ $35.00         │ +25.0% 🔴    │
│ Carne de Res        │ $145.00       │ $158.00        │ +9.0% 🟡     │
│ Aceite de Oliva     │ $385.00       │ $398.00        │ +3.4% 🟢     │
│ Arroz               │ $32.00        │ $31.50         │ -1.6% 💚     │
└─────────────────────┴───────────────┴────────────────┴──────────────┘
```

### 💡 Decisión de Carlos:
- Reducir uso de aguacate en febrero o buscar alternativas
- Hacer compra anticipada de limón antes que suba más
- Mantener compras normales de aceite (subida moderada)

---

## 2️⃣ Pregunta: ¿Cuándo debo comprar para ahorrar?

### Consulta de Carlos:
"¿Hay días específicos donde los precios son mejores?"

### Query Ejecutada:
```sql
SELECT 
    periodo_compra,
    ROUND(AVG(precio_promedio_mercado), 2) as precio_promedio,
    ROUND(MIN(precio_promedio_mercado), 2) as mejor_precio_visto,
    COUNT(DISTINCT producto_id) as productos_analizados,
    CASE 
        WHEN periodo_compra = 'inicio_mes' THEN '✅ RECOMENDADO'
        WHEN periodo_compra = 'quincena' THEN '❌ EVITAR'
        ELSE '➖ Regular'
    END as recomendacion
FROM fact_precio_diario f
JOIN dim_fecha d ON f.fecha_id = d.fecha_id
WHERE categoria_id IN (1, 2, 3)  -- Categorías principales del restaurante
GROUP BY periodo_compra;
```

### Resultado para Carlos:
```
┌─────────────────┬─────────────────┬───────────────────┬──────────────┐
│ Período         │ Precio Promedio │ Mejor Precio      │ Recomendación│
├─────────────────┼─────────────────┼───────────────────┼──────────────┤
│ inicio_mes      │ $142.30         │ $128.50           │ ✅ RECOMENDADO│
│ regular         │ $145.80         │ $131.20           │ ➖ Regular    │
│ quincena        │ $158.90         │ $142.10           │ ❌ EVITAR     │
│ fin_mes         │ $149.20         │ $134.80           │ ➖ Regular    │
└─────────────────┴─────────────────┴───────────────────┴──────────────┘
```

### 📅 Plan de Compras de Carlos para Febrero:
- **5-10 Febrero**: Compra principal del mes (ahorro estimado: 10%)
- **15-16 Febrero**: EVITAR - Precios altos por quincena
- **20-25 Febrero**: Compras complementarias

---

## 3️⃣ Pregunta: ¿Con qué proveedores debo trabajar?

### Consulta de Carlos:
"Quiero los mejores precios pero también confiabilidad"

### Query Ejecutada:
```sql
SELECT 
    p.nombre as proveedor,
    p.tiempo_entrega_dias,
    p.calificacion,
    COUNT(DISTINCT f.producto_id) as productos,
    ROUND(AVG(f.precio_venta / f.precio_promedio_mercado), 3) as indice_precio,
    ROUND(AVG(CASE WHEN f.tiene_stock THEN 1 ELSE 0 END) * 100, 1) as disponibilidad
FROM fact_precio_diario f
JOIN dim_proveedor p ON f.proveedor_id = p.proveedor_id
WHERE f.producto_id IN (
    -- Top 20 productos del restaurante
    SELECT producto_id FROM productos_restaurante_frecuentes LIMIT 20
)
GROUP BY p.proveedor_id, p.nombre, p.tiempo_entrega_dias, p.calificacion
ORDER BY indice_precio;
```

### Resultado para Carlos:
```
┌─────────────────────┬──────────┬──────────────┬───────────┬──────────────┬────────────────┐
│ Proveedor           │ Entrega  │ Calificación │ Productos │ Índice Precio│ Disponibilidad │
├─────────────────────┼──────────┼──────────────┼───────────┼──────────────┼────────────────┤
│ Costco Business     │ 1 día    │ 4.8 ⭐       │ 18/20     │ 0.96 🏆      │ 95.5% ✅       │
│ Restaurant Depot    │ 2 días   │ 4.5 ⭐       │ 17/20     │ 0.98 🥈      │ 92.0% ✅       │
│ La Europea          │ 1 día    │ 4.7 ⭐       │ 12/20     │ 1.15 💰      │ 98.0% ✅       │
└─────────────────────┴──────────┴──────────────┴───────────┴──────────────┴────────────────┘
```

### 🤝 Estrategia de Proveedores de Carlos:
- **Principal (70%)**: Costco - Mejor precio y rapidez
- **Secundario (20%)**: Restaurant Depot - Respaldo confiable
- **Especialidad (10%)**: La Europea - Productos premium específicos

---

## 4️⃣ Resultado: Ahorros Generados en Enero

### Dashboard de Ahorros del Restaurante:
```sql
SELECT 
    COUNT(DISTINCT orden_id) as ordenes_mes,
    ROUND(SUM(total_pagado), 2) as gasto_total,
    ROUND(SUM(ahorro_vs_promedio), 2) as ahorro_generado,
    ROUND(AVG(porcentaje_ahorro), 2) as ahorro_promedio_pct
FROM fact_compras_ahorro
WHERE cliente_id = 501  -- El Buen Sabor
  AND fecha_id BETWEEN 20240101 AND 20240131;
```

### Resultado:
```
📊 RESUMEN DE AHORROS - ENERO 2024
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🏢 Restaurante: El Buen Sabor

💰 Gasto Total: $148,750.00
✅ Ahorro Generado: $7,832.50
📊 Porcentaje Ahorrado: 5.3%
📦 Órdenes Realizadas: 12

TOP 3 PRODUCTOS CON MAYOR AHORRO:
1. Aceite de Oliva 5L: $1,250 (15 cajas)
2. Carne de Res Premium: $2,100 (50 kg)
3. Queso Oaxaca: $890 (30 kg)

💡 Con estos ahorros, Carlos puede:
   - Pagar 2 días de nómina completa
   - Comprar un equipo de cocina nuevo
   - Invertir en marketing digital
```

---

## 📈 Proyección Febrero 2024

### Con las estrategias implementadas:

```
PLAN DE COMPRAS OPTIMIZADO - FEBRERO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📅 Calendario:
   - 5-8 Feb: Compra principal (60% del mes)
   - 12-14 Feb: Complementaria (20%)
   - 19-23 Feb: Productos frescos (20%)

💰 Ahorro Proyectado: $9,500 - $11,000
   - Por timing optimizado: +$2,500
   - Por selección proveedores: +$1,500
   - Por ajustes en productos caros: +$2,000

🎯 Meta: Alcanzar 7-8% de ahorro total
```

---

## 🎯 Conclusiones del Caso

1. **Valor Real**: Carlos ahorró $7,832 en enero (5.3%)
2. **Decisiones Informadas**: Ajustó menú por subida de aguacate
3. **Timing Optimizado**: Evitará comprar en quincenas
4. **Proveedores Correctos**: 70% Costco por mejor precio
5. **ROI de la Plataforma**: 10x el costo de suscripción

## 💬 Testimonio de Carlos

> "Antes compraba cuando se acababan las cosas. Ahora planifico con datos reales. 
> En enero ahorré suficiente para pagar la renta del local por 3 días. 
> Para un restaurante pequeño como el nuestro, cada peso cuenta."

---

## 🚀 Próximos Pasos

1. Configurar alertas cuando aguacate baje de $70
2. Programar órdenes recurrentes para inicio de mes
3. Negociar descuento por volumen con Costco
4. Analizar productos sustitutos para items caros
