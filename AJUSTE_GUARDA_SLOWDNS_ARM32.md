# Ajuste requerido en la Fase 4.35

La Fase 4.35 bloquea SlowDNS en ARM32 porque no existía un binario válido.

Después de instalar `armeabi-v7a/libdns.so`, no conviene borrar todas las
comprobaciones. Sustituye la condición que rechaza siempre ARM32 por una
comprobación de disponibilidad del binario.

Ejemplo conceptual:

```java
private static boolean hasSlowDnsBinary(Context context) {
    ApplicationInfo info = context.getApplicationInfo();
    File nativeDir = new File(info.nativeLibraryDir);
    File binary = new File(nativeDir, "libdns.so");
    return binary.isFile() && binary.canExecute() && binary.length() > 0;
}
```

Antes de iniciar SlowDNS:

```java
if (!hasSlowDnsBinary(context)) {
    // Mostrar el aviso existente y no consumir tiempo.
    return false;
}
```

No uses solamente `Build.SUPPORTED_64_BIT_ABIS` para bloquear el protocolo:
con este nuevo archivo, ARM32 también debe pasar cuando Android haya extraído
la biblioteca correcta para `armeabi-v7a`.

La validación ELF completa se realiza antes de empaquetar mediante
`scripts/validar_libdns_arm32.sh`.
