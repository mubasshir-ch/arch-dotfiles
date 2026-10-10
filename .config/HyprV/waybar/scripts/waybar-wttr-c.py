#!/usr/bin/env python3

import json
import requests
import urllib.parse
from datetime import datetime, date, timedelta

WEATHER_CODES = {
    '113': '☀️ ',
    '116': '⛅ ',
    '119': '☁️ ',
    '122': '☁️ ',
    '143': '🌫️',
    '149': '🌫️',
    '176': '🌧️',
    '179': '🌧️',
    '182': '🌧️',
    '185': '🌧️',
    '200': '⛈️ ',
    '227': '🌨️',
    '230': '🌨️',
    '248': '🌫️',
    '260': '🌫️',
    '263': '🌧️',
    '266': '🌧️',
    '281': '🌧️',
    '284': '🌧️',
    '293': '🌧️',
    '296': '🌧️',
    '299': '🌧️',
    '302': '🌧️',
    '305': '🌧️',
    '308': '🌧️',
    '311': '🌧️',
    '314': '🌧️',
    '317': '🌧️',
    '320': '🌨️',
    '323': '🌨️',
    '326': '🌨️',
    '329': '❄️ ',
    '332': '❄️ ',
    '335': '❄️ ',
    '338': '❄️ ',
    '350': '🌧️',
    '353': '🌧️',
    '356': '🌧️',
    '359': '🌧️',
    '362': '🌧️',
    '365': '🌧️',
    '368': '🌧️',
    '371': '❄️ ',
    '374': '🌨️',
    '377': '🌨️',
    '386': '⛈️ ',
    '389': '⛈️ ',
    '392': '⛈️ ',
    '395': '❄️ '
}

def get_weather_icon(code):
    return WEATHER_CODES.get(str(code), '⛅ ')


def format_time(time):
    return time.replace("00", "").zfill(2)


def format_temp(temp):
    return (temp + "°").ljust(3)


def format_chances(hour):
    chances = {
        "chanceoffog": "Fog",
        "chanceoffrost": "Frost",
        "chanceofovercast": "Overcast",
        "chanceofrain": "Rain",
        "chanceofsnow": "Snow",
        "chanceofsunshine": "Sunshine",
        "chanceofthunder": "Thunder",
        "chanceofwindy": "Wind"
    }

    conditions = []
    for event in chances.keys():
        if int(hour.get(event, 0)) > 0:
            conditions.append(chances[event] + " " + hour[event] + "%")
    return ", ".join(conditions)


data = {}

try:
    # Pure auto-detect query
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
    if location_str:
        tooltip_lines.append(f"<b>📍 {location_str}</b>")
    tooltip_lines.append(f"<b>{curr['weatherDesc'][0]['value']} {curr['temp_C']}°</b>")
    tooltip_lines.append(f"Feels like: {curr['FeelsLikeC']}°")
    tooltip_lines.append(f"Wind: {curr['windspeedKmph']}Km/h")
    tooltip_lines.append(f"Humidity: {curr['humidity']}%")

    now_hour = datetime.now().hour

    for day in weather.get('weather', []):
        day_date_str = day.get('date', '')
        if day_date_str < today_str:
            # Skip past days relative to local timezone
            continue

        if day_date_str == today_str:
            header = f"Today, {day_date_str}"
        elif day_date_str == tomorrow_str:
            header = f"Tomorrow, {day_date_str}"
        else:
            header = day_date_str

        tooltip_lines.append("")
        tooltip_lines.append(f"<b>{header}</b>")
        tooltip_lines.append(f"⬆️ {day['maxtempC']}° ⬇️ {day['mintempC']}° 🌅 {day['astronomy'][0]['sunrise']} 🌇 {day['astronomy'][0]['sunset']}")

        is_today = (day_date_str == today_str)
        for hour in day.get('hourly', []):
            h_int = int(format_time(hour['time']))
            if is_today and h_int < now_hour - 2:
                continue
            h_icon = get_weather_icon(hour.get('weatherCode', ''))
            chances = format_chances(hour)
            chance_str = f", {chances}" if chances else ""
            tooltip_lines.append(f"{format_time(hour['time'])} {h_icon} {format_temp(hour['FeelsLikeC'])} {hour['weatherDesc'][0]['value']}{chance_str}")

    data['tooltip'] = f"<span font_family='JetBrainsMono Nerd Font'>\n" + "\n".join(tooltip_lines) + "\n</span>"
    print(json.dumps(data))
except Exception:
    print(json.dumps({"text": "", "tooltip": ""}))
