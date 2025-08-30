# 📊 Catálogo BI Simplificado - Análisis de Precios

## 🎯 Objetivo
Responder 5 preguntas clave de negocio sobre precios de manera simple y efectiva.

## 📁 Estructura de Archivos

```
catalogo-bi-simplificado/
├── README.md                           # Este archivo
├── 01-preguntas-negocio.md            # Las 5 preguntas que queremos responder
├── 02-modelo-dimensional.md           # Diagrama del modelo estrella simplificado
├── facts/
│   ├── 01-fact-precio-diario.md      # Tabla de hechos principal
│   ├── 02-fact-compras-ahorro.md     # Tabla de ahorros por compra
│   └── 03-metricas-explicadas.md     # Por qué cada métrica es importante
├── dimensiones/
│   ├── 01-dim-producto.md            # Dimensión producto simplificada
│   ├── 02-dim-proveedor.md           # Dimensión proveedor simplificada
│   ├── 03-dim-fecha.md               # Dimensión fecha
│   └── 04-dim-categoria.md           # Dimensión categoría
├── queries/
│   ├── 01-variacion-precios.sql      # Query para variación por categoría
│   ├── 02-productos-volatiles.sql    # Query para volatilidad
│   ├── 03-mejor-momento.sql          # Query para timing óptimo
│   ├── 04-mejores-proveedores.sql    # Query para ranking proveedores
│   └── 05-ahorro-total.sql           # Query para calcular ahorros
└── ejemplos/
    ├── 01-flujo-datos.md              # Ejemplo paso a paso del flujo
    └── 02-caso-uso-real.md           # Caso de uso con datos ejemplo
```

## 🚀 Cómo Usar Esta Documentación

1. **Empieza por** `01-preguntas-negocio.md` para entender qué queremos lograr
2. **Revisa** el modelo dimensional en `02-modelo-dimensional.md`
3. **Explora** las tablas de hechos en la carpeta `facts/`
4. **Entiende** las dimensiones en la carpeta `dimensiones/`
5. **Ejecuta** las queries en la carpeta `queries/`

## 💡 Principios de Simplificación

- ✅ Menos campos, más enfoque
- ✅ Explicación clara del "por qué" de cada campo
- ✅ Ejemplos concretos
- ✅ SQL simple y comentado
- ✅ Un archivo por concepto
