# CI/CD de la organización `hibrusi-dev`

CD centralizado y **multi-VPS**: cada repo despliega por **SSH + `docker compose`**
en uno de dos servidores (`vps1` / `vps2`). La lógica vive **una sola vez** en este
repo (`.github`) y los demás repos solo tienen un *caller* de pocas líneas.

## Piezas

| Archivo | Qué es |
|---|---|
| `.github/workflows/deploy-reusable.yml` | **Reusable workflow** con la lógica (soporta vps1 y vps2). |
| `workflow-templates/deploy.yml` | **Starter template** para repos nuevos (1 clic). |
| `scripts/bootstrap-deploy.sh` | Crea/actualiza el caller en todos los repos (idempotente). |

## Elegir VPS

- **Push a `main`** → despliega al VPS de la variable de repo `DEPLOY_TARGET`
  (`vps1` o `vps2`). Si no la pones, va a `vps1`.
- **Ejecución manual** (*Actions → Deploy → Run workflow*) → eliges `vps1` o `vps2`
  en el desplegable.

## Configuración (una sola vez, a nivel de ORGANIZACIÓN)

`Organización → Settings → Secrets and variables → Actions`

**Secrets** (uno por cada VPS):

| Secret | VPS 1 | VPS 2 |
|---|---|---|
| Host  | `VPS1_HOST` | `VPS2_HOST` |
| Usuario | `VPS1_USER` | `VPS2_USER` |
| Clave privada SSH | `VPS1_SSH_KEY` | `VPS2_SSH_KEY` |
| Puerto (opc, 22) | `VPS1_PORT` | `VPS2_PORT` |

**Variables** (Org level):

| Variable | Valor |
|---|---|
| `DEPLOY_BASE` | carpeta base de los repos en el server (p. ej. `/root`) |
| `DEPLOY_ENABLED` | `true` para activar el despliegue real |
| `DEPLOY_TARGET` | *(opcional, mejor por repo)* `vps1` o `vps2` por defecto de ese repo |

> **Interruptor de seguridad:** mientras `DEPLOY_ENABLED` no valga `true`, los jobs se
> saltan. Tienes los workflows puestos sin que desplieguen nada hasta configurarlo.

### Ruta en el servidor
Por orden: input `deploy_path` → variable de repo `DEPLOY_PATH` →
`DEPLOY_BASE/<nombre-del-repo>`.

## Asignar un repo a vps2
En el repo: *Settings → Secrets and variables → Actions → Variables →* `DEPLOY_TARGET = vps2`.

## Alta de un repo
- **Existentes:** `./scripts/bootstrap-deploy.sh`.
- **Nuevos:** se relanza el script, o *Actions → New workflow → "Deploy a VPS (Docker)"*.
