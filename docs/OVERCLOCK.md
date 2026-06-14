# R36S DarkOS overclock guide

## English

### 1. Important warning

This project modifies the kernel and device tree used by DarkOS on the R36S.

Overclocking and overvolting can cause instability, crashes, filesystem corruption, overheating, permanent hardware damage, or a completely unbootable system.

Use this only if you understand the risk. Keep backups. Test slowly. Do not start directly with the highest frequency.

A cooling mod is strongly recommended, almost mandatory for serious testing above 1416 MHz.

According to Rockchip, 1350 mV is the recommended maximum voltage for RK3326, and 1400 mV is the absolute maximum. Anything above that is outside the specification. I personally do not mind experimenting with my 25 EUR toy, accepting the risk that I may break it. I would never do such a thing with my laptop or phone, for example.

### 2. Available versions

There are three versions.

#### Normal version

Use this version for most original R36S units.

The normal version keeps some safety limits in the kernel. The kernel still applies a real maximum CPU frequency ceiling based on the detected quality of the chip. This means that, in some cases, the system may report a higher requested frequency, but the real applied frequency may be lower.

The normal version also allows the CPU regulator to go up to 1400 mV. This is already above the usual RK3326 specification of 1350 mV, but it is still a relatively reasonable upper limit for careful overclock testing.

This is the recommended version.

#### Extreme version

Use this only for experiments.

The extreme version uses the same default OPP voltage values as the normal version. By default, it still uses up to 1400 mV for the high CPU frequencies.

However, it allows the user to go further manually. The device tree patch raises the CPU regulator maximum to 1450 mV, and the included kernel is less restrictive.

This does not mean that the device will automatically use 1450 mV. It means that tools such as `r36-tuner` can later request higher voltages if the user chooses to do so.

This version has a higher risk of damaging the device.

#### Clone version

This version is compiled for clone units.

I do not own a clone R36S, so I have not been able to test it personally. Use it only if you know that your device is a clone and the normal version is not suitable for your unit.

### 3. Default behavior

After installing either the normal or the extreme version, the default behavior is still conservative.

If you do not add any `max_cpufreq=XXXX` parameter to `boot.ini`, the system will boot with the default maximum CPU frequency:

```text
1296 MHz
````

Both the normal and the extreme versions use the same default voltage values. The difference is not that the extreme version automatically applies higher voltages, but that it allows the user to go further manually.

### 4. Installation

Choose the version you want to use:

```text
/              -> normal version
/extreme       -> extreme experimental version
/clones        -> clone version
```

Copy the files from the chosen folder to the `BOOT` partition of your DarkOS SD card.

The required files are:

```text
dtc.exe
Image.oc
install_r36s_oc.bat
instalar_r36s_oc.bat
```

The `BOOT` partition must also contain the original DarkOS files:

```text
rk3326-r36s-linux.dtb
Image
boot.ini
```

Run one of the installers:

```text
install_r36s_oc.bat
```

or:

```text
instalar_r36s_oc.bat
```

The installer will create backups:

```text
rk3326-r36s-linux.dtb.original
Image.original
```

Then it will patch:

```text
rk3326-r36s-linux.dtb
Image
```

If the `.original` files already exist, they will not be overwritten.

### 5. Editing boot.ini

Open `boot.ini` in the `BOOT` partition.

Find the kernel command line, usually a line that starts with something like:

```text
setenv bootargs
```

Add these two parameters at the end of the existing boot arguments:

```text
max_cpufreq=XXXX boot_cpufreq=1296
```

Replace `XXXX` with the desired maximum CPU frequency.

Available values:

```text
1368
1416
1440
1464
1488
1512
```

Recommended first test:

```text
max_cpufreq=1368 boot_cpufreq=1296
```

Do not copy a whole `boot.ini` line from another device. Keep your existing line and only add the overclock parameters at the end.

### 6. Why use boot_cpufreq during boot?

The parameter:

```text
boot_cpufreq=1296
```

sets a safe initial CPU frequency limit during boot.

`max_cpufreq=XXXX` unlocks the selected maximum frequency and makes it available in `scaling_available_frequencies`. `boot_cpufreq=1296` keeps the initial boot-time CPU frequency limit at 1296 MHz, so the system does not try to jump to an unstable overclock frequency too early.

The recommended setup is to leave `boot_cpufreq=1296` for safer booting, and then raise the CPU frequency later from userspace, for example with `r36-tuner` or your own startup script.

### 7. Recommended tuning procedure

Do not start with the highest frequency.

The safest method is to work step by step.

#### Step 1: Install the patch

Run the installer first.

Do not add any overclock parameter yet. Boot once with the default configuration.

The system should boot at:

```text
1296 MHz
```

This confirms that the patched kernel and DTB boot correctly before adding overclock settings.

#### Step 2: Open r36-tuner

Use `r36-tuner` for voltage tuning:

```text
https://github.com/zenmode-adri/r36-tuner
```

Open:

```text
CPU undervolt -> fine tuning
```

At the default 1296 MHz setting, lower the voltage gradually and test stability.

The goal is not simply to use the lowest possible voltage. The goal is to find a voltage that is stable.

If the device crashes, freezes, reboots, or shows strange behavior, go back to the previous stable value and leave some margin.

#### Step 3: Add 1368 MHz

Edit `boot.ini` and add:

```text
max_cpufreq=1368 boot_cpufreq=1296
```

Boot the device.

Then open `r36-tuner` again and repeat the voltage fine tuning for 1368 MHz.

Test with real emulation workloads, not only menus.

#### Step 4: Move upward gradually

If 1368 MHz is stable, try the next frequency:

```text
1416
```

Then:

```text
1440
1464
1488
1512
```

Always test one step at a time.

At each frequency:

1. Edit `boot.ini`.
2. Boot with `boot_cpufreq=1296`.
3. Use `r36-tuner`.
4. Tune voltage carefully.
5. Test stability under real load.
6. Keep notes of what works.

Do not assume that because one frequency boots, it is fully stable.

### 8. Suggested test order

Recommended order:

```text
1296 -> 1368 -> 1416 -> 1440 -> 1464 -> 1488 -> 1512
```

Recommended first overclock:

```text
1368 MHz
```

Most users should stop at the highest frequency that is stable without excessive voltage or heat.

### 9. Cooling

A cooling mod is strongly recommended.

For 1416 MHz and above, it is almost mandatory.

Without improved cooling, the device may seem stable at first but fail after several minutes of load. Heat can also reduce the lifespan of the device.

Possible cooling improvements include copper shims, thermal pads, contact with the rear shell, or an external heatsink mod. Make sure that nothing shorts the board.

### 10. Notes about reported versus real frequency

On RK3326 devices, reported frequency and real effective frequency may not always match.

The normal version keeps a kernel-side safety mechanism that may cap the real maximum frequency based on chip quality. Therefore, a requested or reported frequency may be higher than the actual effective frequency. In the “extreme” version, we have tried to remove this safety restriction, so the reported and real frequencies should match in most cases. However, even in this case, we have sometimes observed some differences.

To verify real CPU frequency, use a benchmark or timing tool, not only the value reported by the kernel.

### 11. Recovery

If the device does not boot:

1. Remove the SD card.
2. Open the `BOOT` partition on a computer.
3. Remove the `max_cpufreq=XXXX` parameter from `boot.ini`. If needed, also remove `boot_cpufreq=YYYY`.
4. Try booting again.

If needed, restore the original files:

```text
rk3326-r36s-linux.dtb.original -> rk3326-r36s-linux.dtb
Image.original                  -> Image
```

If the `.original` files exist, they should be the original backups created by the first run of the installer.

---

# Guía de overclock para R36S con DarkOS

## Español

### 1. Advertencia importante

Este proyecto modifica el kernel y el device tree usados por DarkOS en la R36S.

El overclock y el overvolt pueden causar inestabilidad, cuelgues, corrupción del sistema de archivos, sobrecalentamiento, daños permanentes en el hardware o que el sistema deje de arrancar.

Úsalo solo si entiendes el riesgo. Conserva copias de seguridad. Prueba poco a poco. No empieces directamente por la frecuencia más alta.

Se recomienda encarecidamente hacer un cooling mod; para pruebas serias por encima de 1416 MHz es casi obligatorio.

Según Rockchip, 1350 mV es el voltaje máximo recomendado para el RK3326, y 1400 mV es el máximo absoluto. Cualquier valor por encima de eso queda fuera de especificación. Personalmente, no me importa experimentar con mi juguete de 25 EUR, aceptando el riesgo de romperlo. No haría nunca algo así con mi portátil o mi teléfono, por ejemplo.

### 2. Versiones disponibles

Hay tres versiones.

#### Versión normal

Usa esta versión para la mayoría de R36S originales.

La versión normal mantiene algunas medidas de seguridad en el kernel. El kernel sigue aplicando un techo de frecuencia máxima real basado en la calidad detectada del chip. Esto significa que, en algunos casos, el sistema puede reportar una frecuencia solicitada más alta, pero la frecuencia real aplicada puede ser inferior.

La versión normal también permite que el regulador de CPU llegue hasta 1400 mV. Esto ya está por encima de la especificación habitual del RK3326, que es 1350 mV, pero sigue siendo un límite relativamente razonable para pruebas cuidadosas de overclock.

Esta es la versión recomendada.

#### Versión extreme

Usa esta versión solo para experimentos.

La versión extreme usa los mismos valores de voltaje OPP por defecto que la versión normal. Por defecto, sigue usando hasta 1400 mV para las frecuencias altas de CPU.

Sin embargo, permite al usuario ir más allá manualmente. El parche del device tree sube el máximo del regulador de CPU hasta 1450 mV, y el kernel incluido es menos restrictivo.

Esto no significa que el dispositivo vaya a usar automáticamente 1450 mV. Significa que herramientas como `r36-tuner` pueden pedir voltajes más altos después, si el usuario decide hacerlo.

Esta versión tiene más riesgo de dañar el dispositivo.

#### Versión clones

Esta versión está compilada para consolas clon.

No tengo una R36S clon, así que no he podido probarla personalmente. Úsala solo si sabes que tu dispositivo es un clon y la versión normal no es adecuada para tu consola.

### 3. Comportamiento por defecto

Después de instalar la versión normal o la versión extreme, el comportamiento por defecto sigue siendo conservador.

Si no añades ningún parámetro `max_cpufreq=XXXX` en `boot.ini`, el sistema arrancará con la frecuencia máxima por defecto:

```text
1296 MHz
```

Tanto la versión normal como la versión extreme usan los mismos valores de voltaje por defecto. La diferencia no es que la versión extreme aplique automáticamente más voltaje, sino que permite al usuario ir más allá manualmente.

### 4. Instalación

Elige la versión que quieras usar:

```text
/              -> versión normal
/extreme       -> versión experimental extreme
/clones        -> versión para consolas clon
```

Copia los archivos de la carpeta elegida a la partición `BOOT` de la tarjeta SD de DarkOS.

Los archivos necesarios son:

```text
dtc.exe
Image.oc
install_r36s_oc.bat
instalar_r36s_oc.bat
```

La partición `BOOT` debe contener también los archivos originales de DarkOS:

```text
rk3326-r36s-linux.dtb
Image
boot.ini
```

Ejecuta uno de los instaladores:

```text
install_r36s_oc.bat
```

o:

```text
instalar_r36s_oc.bat
```

El instalador creará copias de seguridad:

```text
rk3326-r36s-linux.dtb.original
Image.original
```

Después parcheará:

```text
rk3326-r36s-linux.dtb
Image
```

Si ya existen los archivos `.original`, no serán sobrescritos.

### 5. Edición de boot.ini

Abre `boot.ini` en la partición `BOOT`.

Busca la línea de comandos del kernel, normalmente una línea que empieza con algo parecido a:

```text
setenv bootargs
```

Añade estos dos parámetros al final de los argumentos de arranque existentes:

```text
max_cpufreq=XXXX boot_cpufreq=1296
```

Sustituye `XXXX` por la frecuencia máxima de CPU deseada.

Valores disponibles:

```text
1368
1416
1440
1464
1488
1512
```

Primera prueba recomendada:

```text
max_cpufreq=1368 boot_cpufreq=1296
```

No copies una línea completa de `boot.ini` tomada de otro dispositivo. Conserva tu línea actual y añade solo los parámetros de overclock al final.

### 6. Por qué usar boot_cpufreq durante el arranque

El parámetro:

```text
boot_cpufreq=1296
```

establece un límite inicial seguro de frecuencia de CPU durante el arranque.

`max_cpufreq=XXXX` desbloquea la frecuencia máxima elegida y la deja disponible en `scaling_available_frequencies`. `boot_cpufreq=1296` mantiene el límite inicial de frecuencia durante el arranque en 1296 MHz, para que el sistema no intente saltar demasiado pronto a una frecuencia de overclock inestable.

La configuración recomendada es dejar `boot_cpufreq=1296` para que el arranque sea más seguro, y después subir la frecuencia desde userspace, por ejemplo con `r36-tuner` o con tu propio script de arranque.

### 7. Procedimiento recomendado de ajuste

No empieces por la frecuencia más alta.

El método más seguro es trabajar paso a paso.

#### Paso 1: instalar el parche

Ejecuta primero el instalador.

No añadas todavía ningún parámetro de overclock. Arranca una vez con la configuración por defecto.

El sistema debería arrancar a:

```text
1296 MHz
```

Esto confirma que el kernel y el DTB parcheados arrancan correctamente antes de añadir overclock.

#### Paso 2: abrir r36-tuner

Usa `r36-tuner` para el ajuste de voltajes:

```text
https://github.com/zenmode-adri/r36-tuner
```

Abre:

```text
CPU undervolt -> fine tuning
```

En la configuración por defecto de 1296 MHz, baja el voltaje gradualmente y prueba la estabilidad.

El objetivo no es simplemente usar el voltaje más bajo posible. El objetivo es encontrar un voltaje estable.

Si la consola se cuelga, se congela, se reinicia o muestra comportamientos extraños, vuelve al último valor estable y deja algo de margen.

#### Paso 3: añadir 1368 MHz

Edita `boot.ini` y añade:

```text
max_cpufreq=1368 boot_cpufreq=1296
```

Arranca la consola.

Después abre otra vez `r36-tuner` y repite el ajuste fino de voltaje para 1368 MHz.

Prueba con emulación real, no solo en los menús.

#### Paso 4: subir gradualmente

Si 1368 MHz es estable, prueba la siguiente frecuencia:

```text
1416
```

Después:

```text
1440
1464
1488
1512
```

Prueba siempre de una en una.

En cada frecuencia:

1. Edita `boot.ini`.
2. Arranca con `boot_cpufreq=1296`.
3. Usa `r36-tuner`.
4. Ajusta el voltaje con cuidado.
5. Prueba estabilidad con carga real.
6. Anota qué valores funcionan.

No des por hecho que una frecuencia es totalmente estable solo porque arranca.

### 8. Orden de prueba sugerido

Orden recomendado:

```text
1296 -> 1368 -> 1416 -> 1440 -> 1464 -> 1488 -> 1512
```

Primer overclock recomendado:

```text
1368 MHz
```

La mayoría de usuarios debería quedarse en la frecuencia más alta que sea estable sin voltaje o temperatura excesivos.

### 9. Refrigeración

Se recomienda encarecidamente hacer un cooling mod.

Para 1416 MHz y superiores es casi obligatorio.

Sin mejorar la refrigeración, el dispositivo puede parecer estable al principio pero fallar después de varios minutos de carga. El calor también puede reducir la vida útil del dispositivo.

Posibles mejoras incluyen láminas de cobre, thermal pads, contacto con la carcasa trasera o un disipador externo. Asegúrate de que nada provoque un corto en la placa.

### 10. Notas sobre frecuencia reportada y frecuencia real

En dispositivos RK3326, la frecuencia reportada y la frecuencia real efectiva no siempre coinciden.

La versión normal mantiene un mecanismo de seguridad en el kernel que puede limitar la frecuencia máxima real según la calidad del chip. Por eso, una frecuencia solicitada o reportada puede ser superior a la frecuencia efectiva real. En la versión "extreme" se ha intentado eliminar esta restricción de seguridad, de manera que las frecuencias coincidirán en la mayoría de los casos. Pero aún en este caso, hemos observado algunas diferencias a veces.

Para verificar la frecuencia real de CPU, usa una herramienta de benchmark o medición temporal, no solo el valor reportado por el kernel.

### 11. Recuperación

Si la consola no arranca:

1. Retira la tarjeta SD.
2. Abre la partición `BOOT` en un ordenador.
3. Elimina el parámetro `max_cpufreq=XXXX` de `boot.ini`. Si hace falta, elimina también `boot_cpufreq=YYYY`.
4. Prueba a arrancar de nuevo.

Si hace falta, restaura los archivos originales:

```text
rk3326-r36s-linux.dtb.original -> rk3326-r36s-linux.dtb
Image.original                  -> Image
```

Si existen los archivos `.original`, deberían ser las copias originales creadas por la primera ejecución del instalador.

```
```

