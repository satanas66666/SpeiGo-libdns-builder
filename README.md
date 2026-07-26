# SpeiGo VPN — compilación real de `libdns.so` ARM32

Este paquete genera un **ejecutable Android real** para:

- ABI: `armeabi-v7a`
- CPU: ARMv7 (`GOARM=7`)
- Android mínimo: API 21 / Android 5.0
- Formato esperado: `ELF 32-bit LSB pie executable, ARM, EABI5`
- Nombre de entrega: `libdns.so`
- Programa compilado: `dnstt-client`
- Destino en SpeiGo VPN:
  `app/src/main/jniLibs/armeabi-v7a/libdns.so`

El archivo de ARM64 se conserva en:

`app/src/main/jniLibs/arm64-v8a/libdns.so`

## Opción recomendada: GitHub Actions

Esta opción no depende del NDK instalado en AndroidIDE.

1. Crea un repositorio privado vacío en GitHub.
2. Sube todo el contenido de este paquete.
3. Abre la pestaña **Actions**.
4. Ejecuta **Compilar libdns ARM32 API21**.
5. Descarga el artefacto:
   `SpeiGo-libdns-armeabi-v7a-api21`
6. Dentro estará:
   - `libdns.so`
   - `VALIDACION_LIBDNS.txt`
   - `SHA256SUMS.txt`

El workflow instala Go y Android NDK, compila el cliente y rechaza la salida si
no es ELF32, ARM, EABI5 o PIE.

## Compilación local en Linux

Requisitos:

- Git
- Go 1.24 o superior
- Android NDK r27d o compatible
- `readelf`, `file`, `strings`, `sha256sum`

Ejemplo:

```bash
export ANDROID_NDK_ROOT="$HOME/Android/Sdk/ndk/27.3.13750724"
chmod +x scripts/*.sh
./scripts/compilar_libdns_arm32_api21.sh
```

Salida:

```text
out/libdns.so
out/VALIDACION_LIBDNS.txt
out/SHA256SUMS.txt
```

## Instalar en la Fase 4.35

```bash
./scripts/instalar_en_speigo_fase4_35.sh /ruta/al/proyecto/SpeiGo_VPN
```

El instalador:

1. Comprueba que exista el ARM64 actual.
2. Guarda su SHA-256.
3. Copia solamente el ARM32.
4. Vuelve a comprobar el SHA-256 del ARM64.
5. Falla si el ARM64 fue modificado.

## Importante sobre la guarda de compatibilidad

La Fase 4.35 bloquea SlowDNS en ARM32 porque el binario auténtico no estaba
incluido. Después de agregar este archivo, la guarda Java debe comprobar la
existencia/arquitectura del binario en vez de bloquear todo ARM32.

No elimines la validación completa. La condición correcta es permitir SlowDNS
cuando el archivo nativo de la ABI seleccionada exista y sea ejecutable.

## Comando compatible

El ejecutable conserva la interfaz de `dnstt-client`:

```text
dnstt-client [-doh URL|-dot ADDR|-udp ADDR]
             (-pubkey PUBKEY|-pubkey-file PUBKEYFILE)
             DOMAIN LOCALADDR
```

La app puede seguir lanzándolo con su línea actual, usando el nombre
`libdns.so` y el proxy local configurado por SpeiGo.

## Qué no hace este paquete

- No reemplaza ni recompila el `libdns.so` ARM64.
- No renombra un ELF ARM64 como ARM32.
- No entrega un ELF Linux `ET_EXEC`.
- No acepta una salida que no sea PIE.
- No modifica automáticamente código Java sin tener el ZIP exacto de la Fase 4.35.
