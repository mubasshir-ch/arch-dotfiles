#!/usr/bin/env python3

import json
import requests
from datetime import datetime

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

data = {}

try:
    weather = requests.get("https://wttr.in/?format=j1", timeout=10).json()
except Exception:
    print(json.dumps({"text": "", "tooltip": ""}))
    exit(0)


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
        if int(hour[event]) > 0:
            conditions.append(chances[event] + " " + hour[event] + "%")
    return ", ".join(conditions)

try:
    curr = weather['current_condition'][0]
    tempint = int(curr['FeelsLikeC'])
    extrachar = '+' if 0 < tempint < 10 else ''

    icon = get_weather_icon(curr.get('weatherCode', ''))
    data['text'] = f"{icon} {extrachar}{curr['FeelsLikeC']}°"

    data['tooltip'] = f"<b>{curr['weatherDesc'][0]['value']} {curr['temp_C']}°</b>\n"
    data['tooltip'] += f"Feels like: {curr['FeelsLikeC']}°\n"
    data['tooltip'] += f"Wind: {curr['windspeedKmph']}Km/h\n"
    data['tooltip'] += f"Humidity: {curr['humidity']}%\n"

    for i, day in enumerate(weather.get('weather', [])):
        data['tooltip'] += "\n<b>"
        if i == 0:
            data['tooltip'] += "Today, "
        elif i == 1:
            data['tooltip'] += "Tomorrow, "
        data['tooltip'] += f"{day['date']}</b>\n"
        data['tooltip'] += f"⬆️ {day['maxtempC']}° ⬇️ {day['mintempC']}° "
        data['tooltip'] += f"🌅 {day['astronomy'][0]['sunrise']} 🌇 {day['astronomy'][0]['sunset']}\n"
        for hour in day.get('hourly', []):
            if i == 0 and int(format_time(hour['time'])) < datetime.now().hour - 2:
                continue
            h_icon = get_weather_icon(hour.get('weatherCode', ''))
            data['tooltip'] += f"{format_time(hour['time'])} {h_icon} {format_temp(hour['FeelsLikeC'])} {hour['weatherDesc'][0]['value']}, {format_chances(hour)}\n"

    print(json.dumps(data))
except Exception:
    print(json.dumps({"text": "", "tooltip": ""}))
