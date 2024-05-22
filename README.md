# app_map_flutter
Programa de ubicación con flutter y la api de google maps

## Getting Started

Actualmente solo esta configurada la API para funcionar en Android.
Para que funcione correctamente debemos acceder al archivo android > app > src > main > AndroidManifest.xml y modificar el siguiente código:

```
<meta-data android:name="com.google.android.geo.API_KEY"
            android:value="YOUR_GOOGLE_API_KEY"/>
```

Donde se debe especificar la api personal de Google Maps.
