# R36S DarkOS CPU Overclock

## English

### 1. Description

This package enables real CPU overclocking on the R36S running DarkOS.

It includes an overclock-enabled kernel `Image.oc` and a patcher for the R36S device tree. The patch adds the required CPU OPPs, voltage limits, and regulator settings needed to use CPU frequencies above the usual 1296 MHz limit.

This is intended for advanced users. Overclocking may cause instability, crashes, data corruption, or hardware damage. Use it at your own risk.

Kernel sources are available here: https://github.com/teacupx/linux-r36s

There are three available packages:

- **Normal**: recommended for most original R36S units.
- **Extreme**: experimental version with fewer limits, intended only for testing.
- **Clones**: build for clone units. I do not own a clone unit, so this version is untested by me.

For a detailed explanation of the differences, when to use each version, and the recommended tuning procedure, read:

https://github.com/teacupx/overclock-r36s/blob/master/docs/OVERCLOCK.md

### 2. Installation

Choose the package you want to use: the normal package, the `extreme` package, or the `clones` package.

Copy the contents of the chosen package to the `BOOT` partition of your DarkOS SD card.

The folder should contain at least:

```
install_r36s_oc.bat
dtc.exe
rk3326-r36s-linux.dtb
Image
Image.oc
```

Then run:

```
install_r36s_oc.bat
```

The installer will do:

```
rk3326-r36s-linux.dtb          -> patched in place
rk3326-r36s-linux.dtb.original -> backup of the original DTB

Image                           -> replaced by Image.oc
Image.original                  -> backup of the original Image
```

After installation, proceed to next section for config, and then safely eject the SD card and boot the R36S.

### 3. Usage

Edit `boot.ini` in the `BOOT` partition and add the following parameters to the kernel command line:

```
max_cpufreq=XXXX boot_cpufreq=1296
```

Replace `XXXX` with the desired maximum CPU frequency in MHz.

Available overclock values:

```
1368
1416
1440
1464
1488
1512
```

Recommended first test:

```
max_cpufreq=1368 boot_cpufreq=1296
```

If 1368 MHz is stable, you can try higher values step by step.

Example inside `boot.ini`:

```
setenv bootargs "root=LABEL=ROOTFS rootwait rw fsck.repair=yes net.ifnames=0 fbcon=rotate:0 console=/dev/ttyFIQ0 quiet splash consoleblank=0 vt.global_cursor_default=0 max_cpufreq=1368 boot_cpufreq=1296"
```

Do not copy the example UUID blindly. Keep your existing `boot.ini` line and only add the two parameters at the end.

`max_cpufreq=XXXX` unlocks the selected maximum frequency and makes it available to the system. `boot_cpufreq=1296` keeps the initial boot-time CPU frequency limit at 1296 MHz.

The recommended setup is to leave `boot_cpufreq=1296` for safer booting, and then raise the CPU frequency later from userspace, for example with `r36-tuner` or your own startup script.

### Notes

If you do not add `max_cpufreq=XXXX`, the system will use the default setting, which is 1296 MHz.

For fine voltage and frequency tuning from userspace, it is recommended to use `r36-tuner`:

```
https://github.com/zenmode-adri/r36-tuner
```

A cooling mod is strongly recommended, almost mandatory, especially if you want to test 1416 MHz or higher. Better cooling improves stability and reduces the risk of thermal problems.

Always test stability gradually. Start at 1368 MHz, then move upward one step at a time.

---

# Overclock de CPU para R36S con DarkOS

## Español

### 1. Descripción

Este paquete permite hacer overclock real de la CPU en la R36S usando DarkOS.

Incluye una `Image.oc` con el kernel preparado para overclock y un parcheador del device tree de la R36S. El parche añade las OPP de CPU necesarias, los límites de voltaje y la configuración del regulador para usar frecuencias por encima del límite habitual de 1296 MHz.

Esto está pensado para usuarios avanzados. El overclock puede causar inestabilidad, cuelgues, corrupción de datos o daños en el hardware. Úsalo bajo tu responsabilidad.

El código fuente del kernel está aquí: https://github.com/teacupx/linux-r36s

Hay tres paquetes disponibles:

- **Normal**: recomendado para la mayoría de R36S originales.
- **Extreme**: versión experimental con menos límites, pensada solo para pruebas.
- **Clones**: compilación para consolas clon. No tengo una consola clon, así que esta versión no la he podido probar personalmente.

Para una explicación detallada de las diferencias, cuándo usar cada versión y el procedimiento recomendado de ajuste, lee:

https://github.com/teacupx/overclock-r36s/blob/master/docs/OVERCLOCK.md

### 2. Instalación

Elige el paquete que quieras usar: el paquete normal, el paquete `extreme` o el paquete `clones`.

Copia el contenido del paquete elegido a la partición `BOOT` de la tarjeta SD de DarkOS.

La carpeta debe contener al menos:

```
instalar_r36s_oc.bat
dtc.exe
rk3326-r36s-linux.dtb
Image
Image.oc
```

Después ejecuta:

```
instalar_r36s_oc.bat
```

El instalador hará lo siguiente:

```
rk3326-r36s-linux.dtb          -> parcheado directamente
rk3326-r36s-linux.dtb.original -> copia de seguridad del DTB original

Image                           -> sustituida por Image.oc
Image.original                  -> copia de seguridad de la Image original
```

Cuando termine, procede al siguiente paso para configurar, y luego expulsa con seguridad la tarjeta SD y arranca la R36S.

### 3. Uso

Edita `boot.ini` en la partición `BOOT` y añade estos parámetros a la línea de comandos del kernel:

```
max_cpufreq=XXXX boot_cpufreq=1296
```

Sustituye `XXXX` por la frecuencia máxima de CPU deseada, en MHz.

Valores de overclock disponibles:

```
1368
1416
1440
1464
1488
1512
```

Prueba inicial recomendada:

```
max_cpufreq=1368 boot_cpufreq=1296
```

Si 1368 MHz es estable, puedes ir probando frecuencias superiores poco a poco.

Ejemplo dentro de `boot.ini`:

```
setenv bootargs "root=LABEL=ROOTFS rootwait rw fsck.repair=yes net.ifnames=0 fbcon=rotate:0 console=/dev/ttyFIQ0 quiet splash consoleblank=0 vt.global_cursor_default=0 max_cpufreq=1368 boot_cpufreq=1296"
```

No copies a ciegas el UUID del ejemplo. Conserva tu línea original de `boot.ini` y añade solo los dos parámetros al final.

`max_cpufreq=XXXX` desbloquea la frecuencia máxima elegida y la deja disponible para el sistema. `boot_cpufreq=1296` mantiene el límite inicial de frecuencia durante el arranque en 1296 MHz.

La configuración recomendada es dejar `boot_cpufreq=1296` para que el arranque sea más seguro, y después subir la frecuencia desde userspace, por ejemplo con `r36-tuner` o con tu propio script de arranque.

### Notas

Si no añades `max_cpufreq=XXXX`, el sistema usará el valor por defecto, que es 1296 MHz.

Para hacer un ajuste fino de voltajes y frecuencias desde userspace, se recomienda usar `r36-tuner`:

```
https://github.com/zenmode-adri/r36-tuner
```

Se recomienda encarecidamente hacer un cooling mod; para probar 1416 MHz o más, es casi obligatorio. Una mejor refrigeración mejora la estabilidad y reduce el riesgo de problemas térmicos.

Prueba siempre la estabilidad de forma gradual. Empieza por 1368 MHz y sube después paso a paso.

```
```
