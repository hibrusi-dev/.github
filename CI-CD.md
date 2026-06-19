# CI/CD de la organización `hibrusi-dev`

CD centralizado: cada repo despliega por **SSH + `docker compose`** en el VPS en cada
push a `main`. La lógica vive **una sola vez** en este repo (`.github`) y los demás
repos solo tienen un *caller* de 8 líneas.

## Piezas

| Archivo | Qué es |
|---|---|
| `.github/workflows/deploy-reusable.yml` | **Reusable workflow** con toda la lógica de despliegue. |
| `workflow-templates/deploy.yml` | **Starter template**: aparece en *Actions → New workflow* de cada repo (añadir con 1 clic). |
| `scripts/bootstrap-deploy.sh` | Mete el caller en todos los repos que aún no lo tengan (idempotente). |

## Configuración (una sola vez, a nivel de ORGANIZACIÓN)

`Organización → Settings → Secrets and variables → Actions`

**Secrets** (Org level, visibles para todos los repos):

| Secret | Valor |
|---|---|
| `DEPLOY_HOST` | IP o dominio del VPS |
| `DEPLOY_USER` | usuario SSH (p. ej. `root`) |
| `DEPLOY_SSH_KEY` | clave **privada** SSH cuya pública está en `authorized_keys` del VPS |
| `DEPLOY_PORT` | *(opcional)* puerto SSH, por defecto 22 |

**Variables** (Org level):

| Variable | Valor |
|---|---|
| `DEPLOY_BASE` | carpeta base donde viven los repos clonados en el server (p. ej. `/root`) |
| `DEPLOY_ENABLED` | `true` para **activar** el despliegue real. Sin esto, los workflows existen pero no despliegan. |

> **Interruptor de seguridad:** mientras `DEPLOY_ENABLED` no valga `true`, los jobs se
> saltan. Así puedes tener los workflows puestos en todos los repos sin que desplieguen
> nada hasta que termines de configurar los secretos.

### Ruta en el servidor

Se resuelve por orden: input `deploy_path` → variable de repo `DEPLOY_PATH` →
`DEPLOY_BASE/<nombre-del-repo>`. Si tus repos están en `/root/<nombre>`, basta con
`DEPLOY_BASE=/root` y no hay que configurar nada por repo.

## Alta de un repo

- **Repos existentes:** `./scripts/bootstrap-deploy.sh` (ya ejecutado en el alta inicial).
- **Repos nuevos:** o se relanza el script, o en el repo: *Actions → New workflow →
  "Deploy a VPS (Docker)"*.

## Requisitos en cada repo / servidor

- El repo debe estar **clonado en el VPS** en su ruta, con `origin` apuntando a GitHub.
- Debe existir un `docker-compose.yml` en esa ruta.
- `Organización → Settings → Actions → General` debe permitir actions de terceros
  (se usa `appleboy/ssh-action`) y el uso de reusable workflows.
