# 🌟 Modelo Dimensional Simplificado

## Diagrama del Modelo Estrella

```
                        DIMENSIONES
    ┌─────────────┐  ┌──────────────┐  ┌─────────────┐  ┌──────────────┐
    │ DIM_PRODUCTO│  │DIM_PROVEEDOR │  │  DIM_FECHA  │  │DIM_CATEGORIA │
    │ ─────────── │  │ ──────────── │  │ ─────────── │  │ ──────────── │
    │ producto_id │  │ proveedor_id │  │  fecha_id   │  │ categoria_id │
    │ nombre      │  │ nombre       │  │  fecha      │  │ nombre       │
    │ marca       │  │ tipo         │  │  dia_semana │  │ nivel1       │
    │ tamaño      │  │ ciudad       │  │  dia_mes    │  │ nivel2       │
    └──────┬──────┘  └──────┬───────┘  └──────┬──────┘  └──────┬───────┘
           │                │                  │                 │
           └────────────────┼──────────────────┼─────────────────┘
                           │                  │
                    ┌──────▼──────────────────▼─────┐
                    │    FACT_PRECIO_DIARIO         │
                    │ ───────────────────────────── │
                    │ producto_id (FK)              │
                    │ proveedor_id (FK)             │
                    │ fecha_id (FK)                 │
                    │ categoria_id (FK)             │
                    │ ----------------------------- │
                    │ precio_venta                  │
                    │ precio_promedio_mercado       │
                    │ precio_minimo_mercado         │
                    │ precio_maximo_mercado         │
                    │ tiene_stock                   │
                    │ es_precio_mas_bajo           │
                    └────────────────────────────────┘
                                  │
                    ┌─────────────▼──────────────────┐
                    │    FACT_COMPRAS_AHORRO         │
                    │ ───────────────────────────── │
                    │ orden_id                       │
                    │ producto_id (FK)               │
                    │ proveedor_id (FK)              │
                    │ fecha_id (FK)                  │
                    │ cliente_id                     │
                    │ ----------------------------- │
                    │ cantidad_comprada              │
                    │ precio_pagado                  │
                    │ precio_promedio_mercado        │
                    │ ahorro_generado                │
                    └────────────────────────────────┘
```

## 📊 ¿Por qué este modelo?

### Modelo Estrella Simple
- **Fácil de entender**: Una tabla central (hechos) conectada a tablas descriptivas (dimensiones)
- **Rápido de consultar**: Menos JOINs = mejor performance
- **Flexible**: Fácil agregar nuevas métricas o dimensiones

### Dos Tablas de Hechos
1. **FACT_PRECIO_DIARIO**: Para análisis de mercado y tendencias
2. **FACT_COMPRAS_AHORRO**: Para medir el valor real entregado

### Cuatro Dimensiones Esenciales
1. **PRODUCTO**: ¿Qué estamos analizando?
2. **PROVEEDOR**: ¿Quién lo vende?
3. **FECHA**: ¿Cuándo?
4. **CATEGORIA**: ¿De qué tipo es?

## 🔑 Claves y Relaciones

- Cada registro en las tablas FACT tiene una combinación única de las claves foráneas
- Las dimensiones pueden cambiar con el tiempo (las manejaremos de forma simple)
- Un producto puede pertenecer a una categoría
- Un proveedor puede vender muchos productos
- Los precios cambian diariamente
