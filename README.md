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
- **Silent Aim 3D (`X, Y, Z`) omnidireccional activo por defecto (`v4.9`)**
  - **Activo al instante sin tecla (`Mode = Always`, `Silent Key = None`, `Use FOV = false`):** engancha automáticamente a jugadores enemigos visibles o en rango cercano (`<= 260m`) sin requerir tecla ni restringir habilidades con un círculo pequeño (el círculo FOV sigue disponible en el menú).
  - **`Auto Buso` activo por defecto:** mantiene encendido el Buso Haki / Aura (`HasBuso`) al ejecutar y tras reaparecer mediante `Remotes.CommF_:InvokeServer("Buso")`, con interruptor en **Silent → Silent Aim Core**.
  - **Modo `Focus 1 Enemy` (`Focus Target` + `Focus Key = G`):** permite fijar un solo enemigo para que todo el Silent Aim se centre exclusivamente en esa persona (incluso fuera del FOV o detrás de la cámara dentro de `MaxDistance`), con selector cíclico en el menú (`Auto` / nombre de jugador, clic derecho vuelve a `Auto`), tecla rápida configurable (`G`) para fijar/soltar al objetivo actual y resaltado `★ [FOCUS]` en ESP y pie de barra.
  - **Fix quirúrgico para Armas (`Guns`) + Supresión de `AimAssist` / `NoSpread`:** desactiva el `CombatController.AimAssist.getTargetInfo` nativo de PC (`40px`) mientras Silent Aim está activo para evitar que arrastre la mira hacia NPCs o cuerpos sin predicción; elimina la dispersión de balas en `CombatUtil.CreateShootAngles` (`NoSpread = true`); lee el origen real del cañón (`ShootAttachment.WorldPosition`); separa **Hitscan M1** (ignorando mobs de `Enemies` y asegurando impacto limpio en `RE/ShootGunEvent`) de **proyectiles y habilidades `Z / X / C / V / F`**, con re-predicción sub-frame `0ms` (`syncInstantSkillPrediction`) antes de `ContextActionService`.
  - **Solucionador analítico 3D (`X = 1.04, Y = 1.00, Z = 1.04`) para izquierda/derecha/arriba/abajo:** resuelve en forma cerrada la intercepción cuadrática 3D, extrapolación sub-paquete a `144Hz` (`StaleStep`), filtro de coherencia lateral (`TrendVel` vs `SmoothedVel` para clavar tanto dashes sostenidos como strafes `A-D-A-D`), motor vertical de 5 estados (**Air-Stall/Hover** con `BodyMover` sin caída falsa, vuelo, ápice de salto/Geppo, caída libre y suelo/techo) y anclaje al centro de masa del pecho sin bamboleo de animaciones.
  - **Filtros PvP reales de Blox Fruits:** `Team / Ally Check` (`AllianceUtil.getIfAllied` + `Marines`), `Ignore SafeZone` (`InSafeZone`), `Sticky Lock`, `Focus 1 Enemy`, `FOV Circle` opcional, `HitPart` enfocado al pecho por defecto (`Chest` -> `UpperTorso`/`Torso` -> `RootPart`, con opciones `RootPart` y `Closest Body`, sin apuntar a la cabeza) y `Priority` (`Crosshair`, `Closest`, `Lowest HP`).
- **Player ESP (pool `Drawing` perezoso)**
  - `Box Style` (`Corner` / `2D` / `Off`), `Chams Highlights`, `Health Bar`, `Health Text`, `Name & Level`, `Distance`, `Bounty / Safe / Ken` (`[SAFE]` y cargas `[KEN x/y]`), `Fruit / Tool`, `Offscreen Arrows`, `Tracers`, `Skeleton` compatible con **R6 y R15** bajo demanda y alcance configurable hasta `20000`.
