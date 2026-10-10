#!/usr/bin/env python3

import json
import requests
import urllib.parse
from datetime import datetime, date, timedelta

# Nerd Font weather icons matching JetBrainsMono Nerd Font
WEATHER_ICONS = {
    '113': '󰖙', # Sunny / Clear
    '116': '󰖕', # Partly cloudy
    '119': '󰖐', # Cloudy
    '122': '󰖐', # Overcast
    '143': '󰖑', # Mist
    '149': '󰖑', # Smoky haze
    '176': '󰖖', # Patchy rain
    '179': '󰖒', # Patchy snow
    '182': '󰖒', # Patchy sleet
    '185': '󰖒', # Patchy freezing drizzle
    '200': '󰙾', # Thundery outbreaks
    '227': '󰼶', # Blowing snow
    '230': '󰼶', # Blizzard
    '248': '󰖑', # Fog
    '260': '󰖑', # Freezing fog
    '263': '󰖖', # Patchy light drizzle
    '266': '󰖖', # Light drizzle
    '281': '󰖖', # Freezing drizzle
    '284': '󰖖', # Heavy freezing drizzle
    '293': '󰖖', # Patchy light rain
    '296': '󰖖', # Light rain
    '299': '󰖖', # Moderate rain at times
    '302': '󰖖', # Moderate rain
    '305': '󰖒', # Heavy rain at times
    '308': '󰖒', # Heavy rain
    '311': '󰖖', # Light freezing rain
    '314': '󰖒', # Moderate or heavy freezing rain
    '317': '󰖖', # Light sleet
    '320': '󰼶', # Moderate or heavy sleet
    '323': '󰼶', # Patchy light snow
    '326': '󰼶', # Light snow
    '329': '󰼶', # Patchy moderate snow
    '332': '󰼶', # Moderate snow
    '335': '󰼶', # Patchy heavy snow
    '338': '󰼶', # Heavy snow
    '350': '󰖖', # Ice pellets
    '353': '󰖖', # Light rain shower
    '356': '󰖒', # Moderate or heavy rain shower
    '359': '󰖒', # Torrential rain shower
    '362': '󰖖', # Light sleet showers
    '365': '󰖒', # Moderate or heavy sleet showers
    '368': '󰼶', # Light snow showers
    '371': '󰼶', # Moderate or heavy snow showers
    '374': '󰖖', # Light showers of ice pellets
    '377': '󰖒', # Moderate or heavy showers of ice pellets
    '386': '󰙾', # Patchy light rain with thunder
    '389': '󰙾', # Moderate or heavy rain with thunder
    '392': '󰙾', # Patchy light snow with thunder
    '395': '󰙾', # Moderate or snow with thunder
}

def get_weather_icon(code):
    return WEATHER_ICONS.get(str(code), '󰖕')


data = {}

try:
    init_res = requests.get("https://wttr.in/?format=j1", timeout=8).json()
except Exception:
    print(json.dumps({"text": "", "tooltip": ""}))
    exit(0)

weather = init_res
location_str = ""

try:
    nearest = init_res.get('nearest_area', [{}])[0]
    city = nearest.get('areaName', [{}])[0].get('value', '').strip()
    country = nearest.get('country', [{}])[0].get('value', '').strip()
    region = nearest.get('region', [{}])[0].get('value', '').strip()

    loc_parts = [p for p in [city, region, country] if p]
    location_str = ", ".join(loc_parts)

    today = date.today()
    today_str = today.isoformat()
    tomorrow_str = (today + timedelta(days=1)).isoformat()
    weather_dates = [d.get('date') for d in init_res.get('weather', [])]

    # If the default auto-detected response dates lag behind local timezone date,
    # re-query wttr.in using the dynamically detected city name to align with local day
    if city and (not weather_dates or weather_dates[0] != today_str):
        try:
            loc_res = requests.get(f"https://wttr.in/{urllib.parse.quote(city)}?format=j1", timeout=8).json()
            if loc_res.get('weather'):
                weather = loc_res
        except Exception:
            pass

    curr = weather['current_condition'][0]
    tempint = int(curr['FeelsLikeC'])
    extrachar = '+' if 0 < tempint < 10 else ''

    icon = get_weather_icon(curr.get('weatherCode', ''))
    data['text'] = f"{icon} {extrachar}{curr['FeelsLikeC']}°"

    tooltip_lines = []
    
    # 1. Location & Current Status Header
    c_desc = curr['weatherDesc'][0]['value'].strip()
    if location_str:
        tooltip_lines.append(f"<span color='#cba6f7'><b>📍 {location_str}</b></span>")
    tooltip_lines.append(f"<span color='#fab387'><b>{icon}  {c_desc}</b></span>   <b>{curr['temp_C']}°C</b>  (Feels <b>{curr['FeelsLikeC']}°C</b>)")
    tooltip_lines.append(f"<span color='#89dceb'>󰖝</span> {curr['windspeedKmph']:>2} km/h    <span color='#a6e3a1'>󰖎</span> {curr['humidity']:>2}%    <span color='#f9e2af'>󰖙</span> UV {curr.get('uvIndex', '0')}")
    tooltip_lines.append("")

    now_hour = datetime.now().hour

    # 2. Daily Forecasts in Tabular Layout
    for day in weather.get('weather', []):
        day_date_str = day.get('date', '')
        if day_date_str < today_str:
            continue

        if day_date_str == today_str:
            d_title = "Today"
        elif day_date_str == tomorrow_str:
            d_title = "Tomorrow"
        else:
            # Keep only Today and Tomorrow
            continue

        # Day summary
        tooltip_lines.append(f"<span color='#f9e2af'><b>{d_title} · {day_date_str}</b></span>")
        tooltip_lines.append(f"<span color='#f38ba8'> {day['maxtempC']}°</span>  <span color='#89b4fa'> {day['mintempC']}°</span>    <span color='#fab387'>󰖜</span> {day['astronomy'][0]['sunrise']}   <span color='#f5c2e7'>󰖛</span> {day['astronomy'][0]['sunset']}")
        
        # Table column headers
        tooltip_lines.append("<span color='#6c7086'>Time   Weather        Temp  Feel    󰖗     󰖝       󰖎</span>")
        tooltip_lines.append("<span color='#313244'>────────────────────────────────────────────────</span>")

        is_today = (day_date_str == today_str)
        for hour in day.get('hourly', []):
            raw_t = int(hour['time']) // 100
            if is_today and raw_t < now_hour - 2:
                continue
            
            t_str = f"{raw_t:02d}:00"
            h_icon = get_weather_icon(hour.get('weatherCode', ''))
            h_desc = hour['weatherDesc'][0]['value'].strip()
            if len(h_desc) > 12:
                h_desc = h_desc[:11] + "…"
            
            temp = f"{hour['tempC']}°"
            feel = f"{hour['FeelsLikeC']}°"
            rain = f"{hour.get('chanceofrain', '0')}%"
            wind = f"{hour.get('windspeedKmph', '0')}k"
            hum = f"{hour.get('humidity', '0')}%"
            
            row = f"{t_str:<5}  {h_icon} {h_desc:<12} {temp:>4}  {feel:>4}  {rain:>5}  {wind:>4}    {hum:>4}"
            tooltip_lines.append(row)
        
        tooltip_lines.append("")

    # 3. Legend at the bottom
    tooltip_lines.append("<span color='#6c7086'><b>Legend:</b></span>")
    tooltip_lines.append("<span color='#a6adc8'> Max    Min   󰖜 Sunrise   󰖛 Sunset</span>")
    tooltip_lines.append("<span color='#a6adc8'>󰖗 Rain  󰖝 Wind  󰖎 Humidity  UV UV Index</span>")

    data['tooltip'] = f"<span font_family='JetBrainsMono Nerd Font'>\n" + "\n".join(tooltip_lines) + "\n</span>"
    print(json.dumps(data))
except Exception:
    print(json.dumps({"text": "", "tooltip": ""}))
