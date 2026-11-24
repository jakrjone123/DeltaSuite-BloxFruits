# Delta Suite — Blox Fruits

Script modular compacto en Luau para **Blox Fruits** (`First / Second / Third Sea`), enfocado en **Silent Aim multi-canal con predicción 3D (`X, Y, Z`)** para habilidades y armas + **Player ESP**.

## Ejecución rápida (Loadstring)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/jakrjone123/DeltaSuite-BloxFruits/main/BloxFruitsSilent.luau"))()
```

O usando el cargador con manejo de errores (`loader.luau`):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/jakrjone123/DeltaSuite-BloxFruits/main/loader.luau"))()
```

## Características incluidas

- **UI táctica compacta (`472 x 396`)**
  - Ventana lateral izquierda (`x = 22px`) para no bloquear el centro de la pantalla ni los clics, tema Obsidian translúcido arrastrable con 2 pestañas (**`Silent`** y **`ESP`**), barra de estado con FPS, ping y objetivo fijado, tecla de menú configurable (`RightControl`) y descarga limpia (`Unload Script`).
- **Silent Aim 3D (`X, Y, Z`) multi-canal activo por defecto (`v4.7`)**
  - **Activo al instante sin tecla (`Mode = Always`, `Silent Key = None`, `Use FOV = false`):** engancha automáticamente a jugadores enemigos visibles o en rango cercano (`<= 260m`) sin requerir tecla ni restringir habilidades con un círculo pequeño (el círculo FOV sigue disponible en el menú).
  - **`Auto Buso` activo por defecto:** mantiene encendido el Buso Haki / Aura (`HasBuso`) al ejecutar y tras reaparecer mediante `Remotes.CommF_:InvokeServer("Buso")`, con interruptor en **Silent → Silent Aim Core**.
  - **Modo `Focus 1 Enemy` (`Focus Target` + `Focus Key = G`):** permite fijar un solo enemigo para que todo el Silent Aim se centre exclusivamente en esa persona (incluso fuera del FOV o detrás de la cámara dentro de `MaxDistance`), con selector cíclico en el menú (`Auto` / nombre de jugador, clic derecho vuelve a `Auto`), tecla rápida configurable (`G`) para fijar/soltar al objetivo actual y resaltado `★ [FOCUS]` en ESP y pie de barra.
  - **Fix completo para Armas de Fuego (`Guns`) + Protección `Safe NPC / Fruit`:** detecta todas las armas vía `WeaponData` (incluyendo `Dragonstorm`, `Skull Guitar`, `Acidum Rifle`, `Kabucha`, `Magma Blaster`, `Venom Bow`, `Bazooka`, `Cannon`, etc.); distingue disparos **Hitscan M1** (apuntado directo al pecho/parte sin obstáculos para que el raycast cliente siempre conecte sobre objetivos en movimiento) de **proyectiles (`Skull Guitar` / `Bazooka` / `Cannon`) y habilidades `Z / X`** (predicción 3D completa), cubre `RE/ShootGunEvent` (tablas anidadas y protección del origen), `ShootFunction`, `RemoteFunctionShoot`, `Tool.RemoteFunction`, `Util.GetMousePoint` (`require(RS.Util)` y submódulo), `CombatUtil.GetTargetPosition` y `ViewportPointToRay` / `ScreenPointToRay` en ventana de disparo sin romper `Dodge`/Dash ni `WrapMouse`.
  - **Predicción cinemática 3D de máxima precisión (`X, Y, Z`):** tracker de desplazamiento por ventana real de paquetes de red (`PacketPos` / `PacketVel` para eliminar picos `3x` de interpolación), suavizado EMA de `Data Ping` (`0.55x RTT`), reseteo instantáneo de aceleración al detenerse o girar brusco (`> 50°`), gravedad parabólica calibrada en saltos y caídas (segura en estado `Flying`) y clamp vertical al terreno.
  - **Filtros PvP reales de Blox Fruits:** `Team / Ally Check` (`AllianceUtil.getIfAllied` + `Marines`), `Ignore SafeZone` (`InSafeZone`), `Sticky Lock`, `Focus 1 Enemy`, `FOV Circle` opcional, `HitPart` enfocado al pecho por defecto (`Chest` -> `UpperTorso`/`Torso` -> `RootPart`, con opciones `RootPart` y `Closest Body`, sin apuntar a la cabeza) y `Priority` (`Crosshair`, `Closest`, `Lowest HP`).
- **Player ESP (pool `Drawing` perezoso)**
  - `Box Style` (`Corner` / `2D` / `Off`), `Chams Highlights`, `Health Bar`, `Health Text`, `Name & Level`, `Distance`, `Bounty / Safe / Ken` (`[SAFE]` y cargas `[KEN x/y]`), `Fruit / Tool`, `Offscreen Arrows`, `Tracers`, `Skeleton` compatible con **R6 y R15** bajo demanda y alcance configurable hasta `20000`.
