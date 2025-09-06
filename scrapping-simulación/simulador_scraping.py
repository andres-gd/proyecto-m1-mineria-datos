import pandas as pd
import json
import random
from datetime import datetime, timedelta
import numpy as np
from typing import List, Dict, Tuple
import os

class SimuladorScraping:
    def __init__(self):
        """Inicializa el simulador cargando los datos de productos y proveedores"""
        self.productos_df = None
        self.proveedores_df = None
        self.categorias_df = None
        self.precios_base = {}
        self.precios_actuales = {}
        
        # Configuración de descuentos con probabilidades
        # Add max_probability as an input parameter to __init__
        self.max_probability = float(input("Enter maximum total probability (0-1): "))
        
        # Define base probabilities that will be scaled
        base_probabilities = {
            0.03: 0.01,   # 3% - 15% probabilidad
            0.05: 0.01,   # 5% - 12% probabilidad
            0.10: 0.01,   # 10% - 10% probabilidad
            0.15: 0.00,   # 15% - 8% probabilidad
            0.20: 0.00,   # 20% - 6% probabilidad
            0.25: 0.00,   # 25% - 4% probabilidad
            0.30: 0.01,   # 30% - 3% probabilidad
            0.35: 0.009,  # 35% - 2% probabilidad
            0.50: 0.001   # 50% - 1% probabilidad
        }
        
        # Scale probabilities to ensure sum is <= max_probability
        total_prob = sum(base_probabilities.values())
        scale_factor = self.max_probability / total_prob if total_prob > 0 else 1
        
        self.descuentos_config = {
            k: v * scale_factor for k, v in base_probabilities.items()
        }
        # Probabilidad de NO tener descuento (39%)
        self.prob_sin_descuento = 0.80
        
        # Rangos de precios base por categoría (en pesos mexicanos)
        self.rangos_precios_categoria = {
            1: (45, 120),    # Aceite de Oliva
            2: (18, 35),     # Leche
            3: (12, 25),     # Gaseosa
            4: (15, 40),     # Papas Fritas
            5: (25, 60),     # Detergente Polvo
            6: (20, 45),     # Pan Integral
            7: (8, 20),      # Verduras Enlatadas
            8: (80, 180),    # Pollo Congelado
            9: (35, 80),     # Cereales
            10: (45, 120),   # Shampoo
            11: (8, 18),     # Salsa de Tomate
            12: (60, 140),   # Jamón
            13: (15, 35),    # Jugo de Naranja
            14: (25, 55),    # Bebidas Energéticas
            15: (12, 30),    # Galletas
            16: (20, 45),    # Suavizante
            17: (8, 20),     # Jabón de Barra
            18: (15, 35),    # Arroz
            19: (25, 60),    # Helados
            20: (40, 100)    # Pasteles
        }
        
    def cargar_datos(self):
        """Carga los datos de los archivos CSV"""
        try:
            self.productos_df = pd.read_csv('dim_producto.csv')
            self.proveedores_df = pd.read_csv('dim_proveedor.csv')
            self.categorias_df = pd.read_csv('dim_categoria.csv')
            print(f"Datos cargados: {len(self.productos_df)} productos, {len(self.proveedores_df)} proveedores")
        except FileNotFoundError as e:
            raise Exception(f"Error al cargar archivos: {e}")
    
    def generar_precio_base(self, producto_id: int, proveedor_id: int) -> Tuple[float, float]:
        """Genera precio base y precio de lista para un producto-proveedor específico"""
        producto = self.productos_df[self.productos_df['producto_id'] == producto_id].iloc[0]
        proveedor = self.proveedores_df[self.proveedores_df['proveedor_id'] == proveedor_id].iloc[0]
        
        categoria_id = producto['categoria_id']
        rango_min, rango_max = self.rangos_precios_categoria.get(categoria_id, (10, 50))
        
        # Ajustar precio según el nivel del proveedor
        multiplicador_proveedor = {
            'economico': 0.85,
            'medio': 1.0,
            'premium': 1.25
        }.get(proveedor['nivel_precio'], 1.0)
        
        # Ajustar según el tamaño del producto
        tamaño = producto['tamaño']
        multiplicador_tamaño = 1.0
        
        if 'ml' in tamaño or 'L' in tamaño:
            if '250ml' in tamaño: multiplicador_tamaño = 0.7
            elif '500ml' in tamaño: multiplicador_tamaño = 0.9
            elif '1L' in tamaño: multiplicador_tamaño = 1.0
            elif '1.5L' in tamaño: multiplicador_tamaño = 1.3
            elif '2L' in tamaño: multiplicador_tamaño = 1.6
            elif '3L' in tamaño: multiplicador_tamaño = 2.2
            elif '5L' in tamaño: multiplicador_tamaño = 3.5
        elif 'g' in tamaño or 'kg' in tamaño:
            if '200g' in tamaño: multiplicador_tamaño = 0.6
            elif '400g' in tamaño: multiplicador_tamaño = 0.8
            elif '500g' in tamaño: multiplicador_tamaño = 0.9
            elif '750g' in tamaño: multiplicador_tamaño = 1.1
            elif '1kg' in tamaño: multiplicador_tamaño = 1.4
            elif '2kg' in tamaño: multiplicador_tamaño = 2.5
        elif 'piezas' in tamaño:
            if '6 piezas' in tamaño: multiplicador_tamaño = 1.2
            elif '12 piezas' in tamaño: multiplicador_tamaño = 2.0
            elif '24 piezas' in tamaño: multiplicador_tamaño = 3.5
        
        precio_base = random.uniform(rango_min, rango_max) * multiplicador_proveedor * multiplicador_tamaño
        precio_lista = precio_base * random.uniform(1.15, 1.35)  # Precio de lista 15-35% más alto
        
        return round(precio_base, 2), round(precio_lista, 2)
    
    def _calcular_descuento(self, fecha, producto_id, proveedor_id):
        """Calcula el descuento a aplicar basado en probabilidades"""
        # Usar fecha y IDs como semilla para consistencia
        semilla = hash(f"{fecha}_{producto_id}_{proveedor_id}_descuento") % 1000000
        random.seed(semilla)
        
        # Generar número aleatorio
        rand = random.random()
        
        # Verificar si no hay descuento
        if rand <= self.prob_sin_descuento:
            return 0.0
        
        # Calcular descuento basado en probabilidades acumulativas
        prob_acumulada = self.prob_sin_descuento
        for descuento, probabilidad in self.descuentos_config.items():
            prob_acumulada += probabilidad
            if rand <= prob_acumulada:
                return descuento
        
        # Fallback (no debería llegar aquí)
        return 0.0
    
    def variar_precio(self, precio_anterior: float, volatilidad: str = 'media') -> float:
        """Varía el precio basado en el precio anterior con límites razonables"""
        # Definir rangos de variación según volatilidad
        rangos_variacion = {
            'baja': (-0.03, 0.03),    # ±3%
            'media': (-0.08, 0.08),   # ±8%
            'alta': (-0.15, 0.15)     # ±15%
        }
        
        min_var, max_var = rangos_variacion.get(volatilidad, (-0.05, 0.05))
        variacion = random.uniform(min_var, max_var)
        
        nuevo_precio = precio_anterior * (1 + variacion)
        
        # Asegurar que el precio no sea menor a 1 peso
        nuevo_precio = max(1.0, nuevo_precio)
        
        return round(nuevo_precio, 2)
    
    def generar_datos_scraping(self, fecha_inicial: str, fecha_final: str) -> List[Dict]:
        """Genera los datos de scraping para el rango de fechas especificado"""
        if not all([self.productos_df is not None, self.proveedores_df is not None]):
            raise Exception("Primero debe cargar los datos con cargar_datos()")
        
        # Convertir fechas
        fecha_inicio = datetime.strptime(fecha_inicial, '%Y-%m-%d')
        fecha_fin = datetime.strptime(fecha_final, '%Y-%m-%d')
        
        if fecha_inicio > fecha_fin:
            raise ValueError("La fecha inicial debe ser anterior a la fecha final")
        
        datos_scraping = []
        fecha_actual = fecha_inicio
        
        # Inicializar precios base para el primer día
        if not self.precios_actuales:
            print("Generando precios base...")
            for _, producto in self.productos_df.iterrows():
                for _, proveedor in self.proveedores_df.iterrows():
                    if proveedor['activo']:  # Solo proveedores activos
                        key = f"{producto['producto_id']}_{proveedor['proveedor_id']}"
                        precio_base, precio_lista = self.generar_precio_base(
                            producto['producto_id'], proveedor['proveedor_id']
                        )
                        self.precios_actuales[key] = {
                            'precio': precio_base,
                            'precio_lista': precio_lista
                        }
        
        print(f"Generando datos desde {fecha_inicial} hasta {fecha_final}...")
        
        while fecha_actual <= fecha_fin:
            fecha_str = fecha_actual.strftime('%Y-%m-%d')
            
            # Generar datos para cada combinación producto-proveedor
            for _, producto in self.productos_df.iterrows():
                for _, proveedor in self.proveedores_df.iterrows():
                    if proveedor['activo']:  # Solo proveedores activos
                        key = f"{producto['producto_id']}_{proveedor['proveedor_id']}"
                        
                        # Obtener volatilidad de la categoría
                        categoria = self.categorias_df[
                            self.categorias_df['categoria_id'] == producto['categoria_id']
                        ].iloc[0]
                        volatilidad = categoria['volatilidad_tipica']
                        
                        # Variar precios (excepto el primer día)
                        if fecha_actual > fecha_inicio:
                            precio_anterior = self.precios_actuales[key]['precio']
                            nuevo_precio = self.variar_precio(precio_anterior, volatilidad)
                            
                            # Ajustar precio de lista proporcionalmente
                            ratio_cambio = nuevo_precio / precio_anterior
                            nuevo_precio_lista = self.precios_actuales[key]['precio_lista'] * ratio_cambio
                            
                            self.precios_actuales[key] = {
                                'precio': nuevo_precio,
                                'precio_lista': round(nuevo_precio_lista, 2)
                            }
                        
                        # Calcular descuento
                        descuento = self._calcular_descuento(
                            fecha_str, 
                            producto['producto_id'], 
                            proveedor['proveedor_id']
                        )
                        
                        # Aplicar descuento al precio final (sin modificar precios_actuales)
                        precio_base_actual = self.precios_actuales[key]['precio']
                        precio_con_descuento = precio_base_actual * (1 - descuento)
                        precio_con_descuento = max(round(precio_con_descuento, 2), 1.0)
                        
                        # Calcular el porcentaje de descuento aplicado
                        descuento_aplicado = 0
                        if precio_con_descuento < precio_base_actual:
                            descuento_aplicado = round((1 - precio_con_descuento / precio_base_actual) * 100)
                        
                        # Crear registro JSON
                        registro = {
                            'proveedor': proveedor['nombre'],
                            'sku': producto['sku'],
                            'nombre': producto['nombre'],
                            'marca': producto['marca'],
                            'tamaño': producto['tamaño'],
                            'precio': precio_con_descuento,
                            'precio_lista': self.precios_actuales[key]['precio_lista'],
                            'descuento': descuento_aplicado,
                            'fecha': fecha_str
                        }
                        
                        datos_scraping.append(registro)
            
            fecha_actual += timedelta(days=1)
            
            # Mostrar progreso
            if fecha_actual.day == 1 or fecha_actual == fecha_fin:
                print(f"Procesado: {fecha_str}")
        
        print(f"Generación completada: {len(datos_scraping)} registros")
        return datos_scraping
    
    def exportar_json(self, datos: List[Dict], nombre_archivo: str = None) -> str:
        """Exporta los datos a un archivo JSON"""
        if nombre_archivo is None:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            nombre_archivo = f'datos_scraping_{timestamp}.json'
        
        with open(nombre_archivo, 'w', encoding='utf-8') as f:
            json.dump(datos, f, ensure_ascii=False, indent=2)
        
        print(f"Datos exportados a: {nombre_archivo}")
        return nombre_archivo
    
    def exportar_por_fecha(self, datos: List[Dict], directorio: str = 'datos_por_fecha') -> None:
        """Exporta los datos organizados por fecha en archivos separados"""
        if not os.path.exists(directorio):
            os.makedirs(directorio)
        
        # Agrupar por fecha
        datos_por_fecha = {}
        for registro in datos:
            fecha = registro['fecha']
            if fecha not in datos_por_fecha:
                datos_por_fecha[fecha] = []
            datos_por_fecha[fecha].append(registro)
        
        # Exportar cada fecha
        for fecha, registros in datos_por_fecha.items():
            nombre_archivo = os.path.join(directorio, f'scraping_{fecha}.json')
            with open(nombre_archivo, 'w', encoding='utf-8') as f:
                json.dump(registros, f, ensure_ascii=False, indent=2)
        
        print(f"Datos exportados por fecha en directorio: {directorio}")
        print(f"Total de archivos generados: {len(datos_por_fecha)}")
    
    def exportar_por_fecha_y_proveedor(self, datos: List[Dict], directorio: str = 'datos_por_fecha_proveedor') -> None:
        """Exporta los datos organizados por fecha y proveedor en archivos separados
        
        Genera un archivo JSON por cada combinación fecha-proveedor.
        Cada archivo contiene todos los productos de ese proveedor para esa fecha.
        
        Args:
            datos: Lista de registros de datos
            directorio: Directorio donde guardar los archivos
        """
        if not os.path.exists(directorio):
            os.makedirs(directorio)
        
        # Agrupar por fecha y proveedor
        datos_agrupados = {}
        for registro in datos:
            fecha = registro['fecha']
            proveedor = registro['proveedor']
            
            # Crear clave única para fecha-proveedor
            clave = f"{fecha}_{proveedor}"
            
            if clave not in datos_agrupados:
                datos_agrupados[clave] = {
                    'fecha': fecha,
                    'proveedor': proveedor,
                    'productos': []
                }
            
            datos_agrupados[clave]['productos'].append(registro)
        
        # Crear estructura de directorios por fecha
        archivos_generados = 0
        fechas_procesadas = set()
        
        for clave, grupo in datos_agrupados.items():
            fecha = grupo['fecha']
            proveedor = grupo['proveedor']
            
            # Crear directorio para la fecha si no existe
            directorio_fecha = os.path.join(directorio, fecha)
            if not os.path.exists(directorio_fecha):
                os.makedirs(directorio_fecha)
            
            # Limpiar nombre del proveedor para usar como nombre de archivo
            proveedor_limpio = proveedor.replace(' ', '_').replace(',', '').replace('.', '').replace('/', '_')
            nombre_archivo = os.path.join(directorio_fecha, f'{proveedor_limpio}.json')
            
            # Exportar datos del proveedor
            with open(nombre_archivo, 'w', encoding='utf-8') as f:
                json.dump(grupo['productos'], f, ensure_ascii=False, indent=2)
            
            archivos_generados += 1
            fechas_procesadas.add(fecha)
        
        print(f"Datos exportados por fecha y proveedor en directorio: {directorio}")
        print(f"Total de fechas procesadas: {len(fechas_procesadas)}")
        print(f"Total de archivos generados: {archivos_generados}")
        
        # Mostrar estructura generada
        proveedores_unicos = len(set(d['proveedor'] for d in datos))
        print(f"Archivos por fecha: {proveedores_unicos} (uno por proveedor)")


def main():
    """Función principal para ejecutar el simulador"""
    simulador = SimuladorScraping()
    
    try:
        # Cargar datos
        simulador.cargar_datos()
        
        # Solicitar fechas al usuario
        print("\n=== Simulador de Datos de Scraping ===")
        fecha_inicial = input("Ingrese la fecha inicial (YYYY-MM-DD): ")
        fecha_final = input("Ingrese la fecha final (YYYY-MM-DD): ")
        
        # Generar datos
        datos = simulador.generar_datos_scraping(fecha_inicial, fecha_final)
        
        # Exportar datos
        print("\nOpciones de exportación:")
        print("1. Archivo único JSON")
        print("2. Archivos separados por fecha")
        print("3. Archivos separados por fecha y proveedor")
        print("4. Todas las opciones")
        
        opcion = input("Seleccione una opción (1-4): ")
        
        if opcion in ['1', '4']:
            archivo_json = simulador.exportar_json(datos)
            print(f"Archivo generado: {archivo_json}")
        
        if opcion in ['2', '4']:
            simulador.exportar_por_fecha(datos)
        
        if opcion in ['3', '4']:
            simulador.exportar_por_fecha_y_proveedor(datos)
        
        print("\n¡Simulación completada exitosamente!")
        
    except Exception as e:
        print(f"Error: {e}")


if __name__ == "__main__":
    main()