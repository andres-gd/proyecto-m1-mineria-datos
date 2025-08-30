# 📊 Métricas Explicadas - ¿Por qué son importantes?

## Métricas de Precio (FACT_PRECIO_DIARIO)

### 💰 Precio de Venta
- **Qué es:** El precio real al que se vende el producto
- **Por qué importa:** Es la base de todo análisis
- **Ejemplo:** Aceite a $385.50

### 📊 Precio Promedio del Mercado
- **Qué es:** Promedio de todos los proveedores ese día
- **Por qué importa:** Para saber si un precio es "bueno" o "malo"
- **Ejemplo:** Si el promedio es $400 y alguien vende a $385, es buen precio

### 📈📉 Precio Mínimo y Máximo del Mercado
- **Qué es:** El rango de precios disponibles
- **Por qué importa:** Muestra la volatilidad y oportunidades
- **Ejemplo:** Si va de $350 a $450, hay mucha variación (oportunidad de ahorro)

### ✅ Indicadores (tiene_stock, es_precio_mas_bajo)
- **Qué son:** Banderas que facilitan el análisis
- **Por qué importan:** Filtrar rápidamente lo relevante
- **Ejemplo:** No tiene sentido analizar precios sin stock

## Métricas de Ahorro (FACT_COMPRAS_AHORRO)

### 💵 Ahorro vs Promedio
- **Qué es:** Cuánto menos pagamos vs el precio promedio
- **Fórmula:** (Precio_Promedio - Precio_Pagado) × Cantidad
- **Ejemplo:** Si el promedio es $400 y pagamos $385 por 10 unidades = $150 de ahorro

### 📊 Porcentaje de Ahorro
- **Qué es:** El ahorro expresado como %
- **Fórmula:** (Ahorro / Precio_Promedio) × 100
- **Ejemplo:** Ahorramos $15 en un producto de $400 = 3.75% de ahorro

## Métricas Calculadas (Queries)

### 📈 Variación de Precio
- **Qué es:** Cambio porcentual entre dos períodos
- **Fórmula:** ((Precio_Nuevo - Precio_Anterior) / Precio_Anterior) × 100
- **Ejemplo:** De $350 a $385 = +10% de aumento

### 🎢 Volatilidad
- **Qué es:** Qué tanto varía el precio
- **Fórmula Simple:** (Precio_Max - Precio_Min) / Precio_Promedio
- **Ejemplo:** Si varía entre $300-$400 con promedio $350 = 28% volatilidad

### 🏆 Frecuencia de Mejor Precio
- **Qué es:** Qué tan seguido un proveedor tiene el mejor precio
- **Fórmula:** (Días_con_mejor_precio / Total_días) × 100
- **Ejemplo:** Costco tuvo el mejor precio 20 de 30 días = 67% líder en precio

## Ventanas de Tiempo Recomendadas

| Métrica | Ventana | ¿Por qué? |
|---------|---------|-----------|
| Precio Promedio | 7 días | Balance entre actualidad y estabilidad |
| Volatilidad | 30 días | Suficientes datos para ver patrones |
| Tendencia | 7-14 días | Detectar cambios recientes |
| Mejor Momento | 90 días | Patrones estacionales |
| Ahorro Total | Mensual | Período contable estándar |

## 🎯 Regla de Oro

> "Una métrica sin contexto no sirve de nada"

Siempre compara:
- Con el período anterior
- Con el promedio del mercado
- Con el objetivo del negocio
