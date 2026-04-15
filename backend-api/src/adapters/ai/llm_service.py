# adapters/ai/llm_service.py
"""
Servicio de IA para interpretar datos de calidad del aire.
Soporta Gemini (gratis) y un proveedor alternativo vía variable LLM_PROVIDER.

El LLM recibe datos combinados del agregador y genera:
- Resumen en lenguaje natural
- Recomendaciones de salud por modo de transporte
- Análisis de concordancia entre fuentes
- Alertas si hay discrepancia o riesgo
"""
import os
import json
import logging
import requests
from django.core.cache import cache

logger = logging.getLogger(__name__)

# Configuración de proveedores LLM
GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models"
ALT_LLM_API_URL = os.environ.get("ALT_LLM_API_URL", "")

# Modos de transporte en español
MODE_LABELS = {
    "walk": "caminar",
    "run": "correr",
    "bike": "bicicleta",
}

SYSTEM_PROMPT = """Eres un experto en calidad del aire y salud ambiental para la app AirWay.
Tu trabajo es analizar datos de múltiples fuentes de calidad del aire y generar
recomendaciones útiles y claras para personas que se desplazan a pie, corriendo o en bicicleta.

REGLAS:
- Responde SIEMPRE en español
- Sé conciso pero informativo (máximo 3-4 oraciones por sección)
- Usa lenguaje accesible, no técnico
- Si las fuentes discrepan mucho (>30 puntos AQI), menciona la incertidumbre
- Adapta las recomendaciones al modo de transporte (mayor esfuerzo = mayor riesgo)
- Incluye emojis relevantes para hacer el texto amigable

Responde SIEMPRE en formato JSON con esta estructura exacta:
{
  "summary": "Resumen general de la calidad del aire",
  "health_recommendation": "Recomendación específica para el modo de transporte",
  "source_agreement": "Nivel de concordancia entre fuentes",
  "alerts": ["lista de alertas si las hay, o vacía"],
  "best_hours": "Mejores horas para salir (si hay pronóstico disponible)",
  "risk_level": "bajo|moderado|alto|muy_alto|peligroso"
}"""


class LLMService:
    """Servicio de IA para análisis de calidad del aire."""

    def __init__(self):
        self.provider = os.environ.get("LLM_PROVIDER", "gemini").lower()
        self.gemini_key = os.environ.get("GEMINI_API_KEY", "")
        self.alt_key = os.environ.get("ALT_LLM_API_KEY", "")
        self.gemini_model = os.environ.get("GEMINI_MODEL", "gemini-2.0-flash-lite")
        self.cache_ttl = 300  # 5 min

    def analyze(self, aggregated_data: dict, mode: str = "walk", forecast: list = None) -> dict:
        """
        Analiza datos combinados de calidad del aire con IA.

        Args:
            aggregated_data: Resultado del AirQualityAggregator
            mode: Modo de transporte (walk/run/bike)
            forecast: Pronóstico horario de Open-Meteo (opcional)

        Returns:
            Análisis estructurado del LLM
        """
        # Cache basado en AQI combinado + modo (evita llamadas repetidas)
        aqi = aggregated_data.get("combined_aqi", 0)
        loc = aggregated_data.get("location", {})
        cache_key = f"llm_analysis:{loc.get('lat', 0):.2f}:{loc.get('lon', 0):.2f}:{aqi}:{mode}"

        cached = cache.get(cache_key)
        if cached:
            logger.info(f"LLM cache hit: {cache_key}")
            return cached

        # Construir el prompt con los datos
        user_prompt = self._build_prompt(aggregated_data, mode, forecast)

        # Llamar al LLM según el proveedor configurado
        try:
            if self.provider == "alt" and self.alt_key:
                raw = self._call_alt_provider(user_prompt)
            elif self.gemini_key:
                raw = self._call_gemini(user_prompt)
            else:
                logger.warning("No hay API key de LLM configurada, usando análisis local")
                return self._local_analysis(aggregated_data, mode)

            result = self._parse_response(raw)
            cache.set(cache_key, result, timeout=self.cache_ttl)
            return result

        except Exception as e:
            logger.error(f"LLM error: {e}")
            return self._local_analysis(aggregated_data, mode)

    def _build_prompt(self, data: dict, mode: str, forecast: list = None) -> str:
        """Construye el prompt con todos los datos disponibles."""
        mode_label = MODE_LABELS.get(mode, mode)

        # Formatear fuentes
        sources_text = ""
        for name, info in data.get("sources", {}).items():
            sources_text += f"  - {name}: AQI={info.get('aqi', 'N/A')}, tipo={info.get('source_type', 'N/A')}"
            if info.get("station_name"):
                sources_text += f", estación={info['station_name']}"
            sources_text += "\n"

        # Formatear contaminantes
        pollutants_text = ""
        for name, info in data.get("pollutants", {}).items():
            if info and info.get("value") is not None:
                pollutants_text += f"  - {name}: {info['value']} {info.get('unit', 'µg/m³')} ({info.get('sources_reporting', 0)} fuentes)\n"

        # Formatear pronóstico si existe
        forecast_text = ""
        if forecast:
            forecast_text = "\nPronóstico próximas horas:\n"
            for entry in forecast[:12]:  # Máximo 12 horas
                forecast_text += f"  - {entry['time']}: AQI={entry.get('aqi', 'N/A')}\n"

        prompt = f"""Analiza los siguientes datos de calidad del aire:

UBICACIÓN: lat={data.get('location', {}).get('lat')}, lon={data.get('location', {}).get('lon')}
AQI COMBINADO: {data.get('combined_aqi', 0)}
CONFIANZA: {data.get('confidence', 0):.0%}
CONTAMINANTE DOMINANTE: {data.get('dominant_pollutant', 'desconocido')}
FUENTES ({data.get('source_count', 0)}):
{sources_text}
CONTAMINANTES:
{pollutants_text}
{forecast_text}
MODO DE TRANSPORTE: {mode_label}

Genera el análisis en formato JSON."""

        return prompt

    def _call_gemini(self, prompt: str) -> str:
        """Llama a la API de Gemini."""
        url = f"{GEMINI_API_URL}/{self.gemini_model}:generateContent"
        params = {"key": self.gemini_key}

        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "systemInstruction": {"parts": [{"text": SYSTEM_PROMPT}]},
            "generationConfig": {
                "temperature": 0.3,
                "maxOutputTokens": 2048,
                "responseMimeType": "application/json",
            },
        }

        r = requests.post(url, params=params, json=payload, timeout=15)
        r.raise_for_status()
        data = r.json()

        # Extraer texto de la respuesta
        candidates = data.get("candidates", [])
        if candidates:
            parts = candidates[0].get("content", {}).get("parts", [])
            if parts:
                return parts[0].get("text", "{}")

        return "{}"

    def _call_alt_provider(self, prompt: str) -> str:
        """Llama a un proveedor LLM alternativo (compatible con OpenAI API)."""
        url = ALT_LLM_API_URL or "https://api.openai.com/v1/chat/completions"
        headers = {
            "Authorization": f"Bearer {self.alt_key}",
            "Content-Type": "application/json",
        }

        payload = {
            "model": os.environ.get("ALT_LLM_MODEL", "gpt-4o-mini"),
            "max_tokens": 800,
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": prompt},
            ],
        }

        r = requests.post(url, headers=headers, json=payload, timeout=15)
        r.raise_for_status()
        data = r.json()

        choices = data.get("choices", [])
        if choices:
            return choices[0].get("message", {}).get("content", "{}")

        return "{}"

    def _parse_response(self, raw: str) -> dict:
        """Parsea la respuesta JSON del LLM."""
        try:
            # Limpiar posibles bloques de código markdown
            cleaned = raw.strip()
            if cleaned.startswith("```"):
                lines = cleaned.split("\n")
                cleaned = "\n".join(lines[1:-1])

            return json.loads(cleaned)
        except json.JSONDecodeError:
            logger.warning(f"No se pudo parsear respuesta LLM: {raw[:200]}")
            return {
                "summary": raw[:300] if raw else "No se pudo generar análisis",
                "health_recommendation": "",
                "source_agreement": "",
                "alerts": [],
                "best_hours": "",
                "risk_level": "desconocido",
            }

    def _local_analysis(self, data: dict, mode: str) -> dict:
        """
        Análisis local sin LLM (fallback).
        Genera recomendaciones basadas en reglas cuando no hay API key.
        """
        aqi = data.get("combined_aqi", 0)
        source_count = data.get("source_count", 0)
        confidence = data.get("confidence", 0)
        dominant = data.get("dominant_pollutant", "pm25")
        mode_label = MODE_LABELS.get(mode, mode)

        # Determinar nivel de riesgo
        if aqi <= 50:
            risk = "bajo"
            summary = f"🟢 La calidad del aire es buena (AQI {aqi}). Condiciones ideales para actividades al aire libre."
            rec = f"Excelente momento para {mode_label}. No se requieren precauciones especiales."
        elif aqi <= 100:
            risk = "moderado"
            summary = f"🟡 La calidad del aire es moderada (AQI {aqi}). Aceptable para la mayoría."
            rec = f"Puedes {mode_label} sin problemas. Personas con asma o sensibilidad respiratoria deben monitorear síntomas."
        elif aqi <= 150:
            risk = "alto"
            summary = f"🟠 Calidad del aire no saludable para grupos sensibles (AQI {aqi})."
            if mode in ("run", "bike"):
                rec = f"Considera reducir la intensidad o duración de tu recorrido en {mode_label}. El ejercicio intenso aumenta la inhalación de partículas."
            else:
                rec = f"Puedes {mode_label} distancias cortas. Evita rutas con tráfico pesado."
        elif aqi <= 200:
            risk = "muy_alto"
            summary = f"🔴 Calidad del aire no saludable (AQI {aqi}). Todos pueden verse afectados."
            rec = f"Se recomienda evitar {mode_label} prolongado. Si es necesario, usa cubrebocas N95."
        else:
            risk = "peligroso"
            summary = f"🟣 Calidad del aire peligrosa (AQI {aqi}). Alerta de salud."
            rec = f"Evita {mode_label} al aire libre. Busca transporte cerrado con filtración de aire."

        # Concordancia de fuentes
        if source_count >= 3:
            agreement = f"✅ {source_count} fuentes reportan datos. Confianza {confidence:.0%}."
        elif source_count == 2:
            agreement = f"⚠️ Solo {source_count} fuentes disponibles. Confianza {confidence:.0%}."
        else:
            agreement = f"⚠️ Solo 1 fuente disponible. Los datos podrían no ser representativos."

        # Alertas
        alerts = []
        if confidence < 0.5:
            alerts.append("Baja confianza en los datos — pocas fuentes o alta discrepancia")
        if dominant == "pm25":
            pm25_data = data.get("pollutants", {}).get("pm25")
            if pm25_data and pm25_data.get("value", 0) > 35:
                alerts.append(f"PM2.5 elevado ({pm25_data['value']} µg/m³) — partículas finas que penetran los pulmones")

        return {
            "summary": summary,
            "health_recommendation": rec,
            "source_agreement": agreement,
            "alerts": alerts,
            "best_hours": "Consulta el pronóstico para mejores horas",
            "risk_level": risk,
        }
