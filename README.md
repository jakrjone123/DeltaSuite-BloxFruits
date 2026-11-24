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
- **Silent Aim 3D (`X, Y, Z`) multi-canal activo por defecto (`v4.8`)**
  - **Activo al instante sin tecla (`Mode = Always`, `Silent Key = None`, `Use FOV = false`):** engancha automáticamente a jugadores enemigos visibles o en rango cercano (`<= 260m`) sin requerir tecla ni restringir habilidades con un círculo pequeño (el círculo FOV sigue disponible en el menú).
  - **`Auto Buso` activo por defecto:** mantiene encendido el Buso Haki / Aura (`HasBuso`) al ejecutar y tras reaparecer mediante `Remotes.CommF_:InvokeServer("Buso")`, con interruptor en **Silent → Silent Aim Core**.
  - **Modo `Focus 1 Enemy` (`Focus Target` + `Focus Key = G`):** permite fijar un solo enemigo para que todo el Silent Aim se centre exclusivamente en esa persona (incluso fuera del FOV o detrás de la cámara dentro de `MaxDistance`), con selector cíclico en el menú (`Auto` / nombre de jugador, clic derecho vuelve a `Auto`), tecla rápida configurable (`G`) para fijar/soltar al objetivo actual y resaltado `★ [FOCUS]` en ESP y pie de barra.
  - **Fix quirúrgico para Armas (`Guns`) + Supresión de `AimAssist` / `NoSpread`:** desactiva el `CombatController.AimAssist.getTargetInfo` nativo de PC (`40px`) mientras Silent Aim está activo para evitar que arrastre la mira hacia NPCs o cuerpos sin predicción; elimina la dispersión de balas en `CombatUtil.CreateShootAngles` (`NoSpread = true`); lee el origen real del cañón (`ShootAttachment.WorldPosition`); separa **Hitscan M1** (ignorando mobs de `Enemies` y asegurando impacto limpio en `RE/ShootGunEvent`) de **proyectiles y habilidades `Z / X / C / V / F`** (incluyendo ventana post-release `+0.42s` para habilidades cargadas), y excluye herramientas utilitarias/Race V3-V4 (`Awakening`, `Heavenly Blood`, etc.).
  - **Balística exacta por habilidad (`PlayerGui.MovesetModules`) + Predicción curva 3D (`TurnRate`):** extrae dinámicamente la velocidad real (`Step * FrameRateScale`, `SpecialSpeed`, `BaseSpeed + SpeedGrowth`, `ServerDashRayDistance / DashTweenTime`) y el windup exacto (`SnakeGenerationDelay`, `ClientReleaseEffectDelay`, `DashTeleportDelay`) de cada habilidad equipada; integra curvatura angular horizontal (`TurnRate` circular exacto en strafe/dash curvo), ventana real de paquetes (`PacketVel`), ping EMA (`0.54x RTT`) y gravedad parabólica calibrada con clamp al terreno.
  - **Filtros PvP reales de Blox Fruits:** `Team / Ally Check` (`AllianceUtil.getIfAllied` + `Marines`), `Ignore SafeZone` (`InSafeZone`), `Sticky Lock`, `Focus 1 Enemy`, `FOV Circle` opcional, `HitPart` enfocado al pecho por defecto (`Chest` -> `UpperTorso`/`Torso` -> `RootPart`, con opciones `RootPart` y `Closest Body`, sin apuntar a la cabeza) y `Priority` (`Crosshair`, `Closest`, `Lowest HP`).
- **Player ESP (pool `Drawing` perezoso)**
  - `Box Style` (`Corner` / `2D` / `Off`), `Chams Highlights`, `Health Bar`, `Health Text`, `Name & Level`, `Distance`, `Bounty / Safe / Ken` (`[SAFE]` y cargas `[KEN x/y]`), `Fruit / Tool`, `Offscreen Arrows`, `Tracers`, `Skeleton` compatible con **R6 y R15** bajo demanda y alcance configurable hasta `20000`.
