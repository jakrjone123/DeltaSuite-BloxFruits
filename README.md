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
- **Silent Aim 3D (`X, Y, Z`) omnidireccional de máxima precisión activo por defecto (`v5.1`)**
  - **Activo al instante sin tecla (`Mode = Always`, `Silent Key = None`, `Use FOV = false`):** engancha automáticamente a jugadores enemigos visibles o en rango cercano (`<= 260m`) sin requerir tecla ni restringir habilidades con un círculo pequeño (el círculo FOV sigue disponible en el menú).
  - **Protección total de Ken, Buso, Haki, Soru, Geppo, Dash y Race V3/V4 (`v5.0`–`v5.1`):** `CommE` y `CommF_` quedan `100%` excluidos de intercepción en `__namecall`, cero llamadas `OP_NAMECALL` (`:`) dentro de cualquier metamétodo, ventana de paso nativo (`ABILITY_BYPASS_KEYS`: `E` Ken, `J` Buso, `R` Soru/Flash Step, `T` Race V3, `Y` Race V4, `Q` Dash) para que `Soru` teletransporte exactamente a tu cursor y ninguna habilidad falle, y `Auto Buso` inteligente (respeta `1.8s` tras reaparecer para no apagar el Buso restaurado por el servidor, respeta la tecla `J` manual y no invoca durante `Busy`/`Stun`).
  - **Modo `Focus 1 Enemy` (`Focus Target` + `Focus Key = U`):** permite fijar un solo enemigo para que todo el Silent Aim se centre exclusivamente en esa persona (incluso fuera del FOV o detrás de la cámara dentro de `MaxDistance`), con selector cíclico en el menú (`Auto` / nombre de jugador, clic derecho vuelve a `Auto`), tecla rápida configurable (`U`, sin colisionar con `G` TAP ni habilidades) y resaltado `★ [FOCUS]` en ESP y pie de barra.
  - **Fix quirúrgico para Armas (`Guns`) + Peek Hitscan + Supresión de `AimAssist` / `NoSpread`:** desactiva el `CombatController.AimAssist.getTargetInfo` nativo de PC (`40px`) mientras Silent Aim está activo; elimina la dispersión de balas en `CombatUtil.CreateShootAngles` (`NoSpread = true`); lee el origen real del cañón (`ShootAttachment.WorldPosition` / `Handle`); separa **Hitscan M1** (con sub-puntos de asomo `±0.62` studs cuando el enemigo cubre medio torso tras cobertura e ignorando mobs de `Enemies`) de **proyectiles y habilidades `Z / X / C / V / F`**, y recalcula la balística en el instante exacto de clic o al soltar habilidades cargadas (`InputEnded`).
  - **Solucionador analítico 3D calibrado al milímetro (`X = 1.05, Y = 1.02, Z = 1.05`, `Skill Speed = 660`, `Cast Lead = 20ms`):** convergencia exacta en 5 pasadas sobre la intercepción cuadrática 3D, filtro de jitter de llegada entre paquetes (`PrevPacketVel`) + filtro de mediana de 3 muestras en ping, fusión instantánea en `Y` (`AssemblyLinearVelocity.Y`) para captar saltos y `Geppo` en el Frame 1, extrapolación sub-paquete a `144Hz/240Hz`, coherencia lateral (`A-D-A-D` vs dashes), **protección anti-pared con deslizamiento tangencial** (`CanCollide` wall-slide) y motor vertical de 5 estados (**Air-Stall/Hover**, vuelo, ápice, caída libre y suelo/techo).
  - **Filtros PvP reales de Blox Fruits:** `Team / Ally Check` (`AllianceUtil.getIfAllied` + `Marines`), `Ignore SafeZone` (`InSafeZone`), `Sticky Lock`, `Focus 1 Enemy`, `FOV Circle` opcional, `HitPart` enfocado al pecho por defecto (`Chest` -> `UpperTorso`/`Torso` -> `RootPart`, con opciones `RootPart` y `Closest Body`, sin apuntar a la cabeza) y `Priority` (`Crosshair`, `Closest`, `Lowest HP`).
- **Player ESP (pool `Drawing` perezoso)**
  - `Box Style` (`Corner` / `2D` / `Off`), `Chams Highlights`, `Health Bar`, `Health Text`, `Name & Level`, `Distance`, `Bounty / Safe / Ken` (`[SAFE]` y cargas `[KEN x/y]`), `Fruit / Tool`, `Offscreen Arrows`, `Tracers`, `Skeleton` compatible con **R6 y R15** bajo demanda y alcance configurable hasta `20000`.
