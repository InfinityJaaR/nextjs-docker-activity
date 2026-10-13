# Next.js + Docker 🐳

Aplicación web creada con `create-next-app` y contenerizada con Docker para garantizar un entorno de ejecución **consistente, aislado y portable**, listo para desplegarse en cualquier entorno de producción que soporte contenedores.

## 🛠️ Tecnologías

- **Framework**: [Next.js 16](https://nextjs.org/) (App Router) + React 19
- **Estilos**: Tailwind CSS v4
- **Tipado**: TypeScript
- **Contenedores**: Docker (multi-stage build) sobre `node:22-alpine`

## 📋 Requisitos

- [Docker](https://docs.docker.com/get-docker/) 24 o superior (Docker Engine o Docker Desktop)
- Opcional, para desarrollo sin Docker: Node.js ≥ 20.9 y npm

## 🚀 Construir y ejecutar el contenedor

### 1. Construir la imagen

Desde la raíz del proyecto (donde está el `Dockerfile`):

```bash
docker build -t nextjs-docker-app .
```

### 2. Ejecutar el contenedor

```bash
docker run -d -p 3000:3000 --name nextjs-docker nextjs-docker-app
```

Abrir [http://localhost:3000](http://localhost:3000) en el navegador.

> Para usar otro puerto en el host, cambiar solo el primer número: `-p 8080:3000` → http://localhost:8080

### 3. Verificar que funciona

```bash
docker ps                               # el contenedor aparece como "Up ... (healthy)"
docker logs nextjs-docker               # debe mostrar "✓ Ready in ..."
curl -I http://localhost:3000           # debe responder HTTP/1.1 200 OK
docker images nextjs-docker-app         # tamaño de la imagen final
```

### 4. Detener y eliminar el contenedor

```bash
docker stop nextjs-docker
docker rm nextjs-docker
```

### Variables de entorno

Los archivos `.env*` **no se copian a la imagen** (están en `.dockerignore`). Para pasar variables en tiempo de ejecución:

```bash
docker run -d -p 3000:3000 --env-file .env --name nextjs-docker nextjs-docker-app
# o una por una
docker run -d -p 3000:3000 -e MI_VARIABLE=valor --name nextjs-docker nextjs-docker-app
```

> Las variables `NEXT_PUBLIC_*` se incrustan en el JavaScript del cliente durante `next build`, por lo que deben estar disponibles al construir la imagen, no solo al ejecutarla.

## 🧱 Estructura del Dockerfile (multi-stage build)

El `Dockerfile` separa el proceso en tres etapas. Solo la última forma parte de la imagen final, así que las herramientas de compilación y las dependencias de desarrollo no llegan a producción.

| Etapa     | Base              | Qué hace                                                                                         |
| --------- | ----------------- | ------------------------------------------------------------------------------------------------ |
| `deps`    | `node:22-alpine`  | Copia `package.json` y `package-lock.json` e instala dependencias con `npm ci` (reproducible).   |
| `builder` | `node:22-alpine`  | Copia el código y `node_modules`, ejecuta `npm run build` (`next build`).                        |
| `runner`  | `node:22-alpine`  | Copia solo la salida *standalone*, `public/` y `.next/static`; expone el puerto 3000 y arranca.   |

Buenas prácticas aplicadas:

- **Caché de capas**: los manifiestos se copian antes que el código, así `npm ci` solo se repite cuando cambian las dependencias.
- **`npm ci`**: instala exactamente las versiones del `package-lock.json`, garantizando builds reproducibles.
- **Salida `standalone`** (`output: "standalone"` en `next.config.ts`): Next.js copia solo los archivos y módulos necesarios para ejecutar la app, lo que reduce mucho el tamaño de la imagen.
- **Usuario sin privilegios**: el contenedor se ejecuta como `nextjs` (uid 1001), no como `root`.
- **`HEALTHCHECK`**: Docker comprueba periódicamente que el servidor responde.
- **Telemetría desactivada** con `NEXT_TELEMETRY_DISABLED=1`.

### ¿Por qué `node:22-alpine` y no `node:18-alpine`?

La versión actual de `create-next-app` genera un proyecto con **Next.js 16, que requiere Node.js ≥ 20.9**; con `node:18-alpine` el build falla. Además, Node.js 18 llegó al final de su soporte (EOL) en abril de 2025 y ya no recibe parches de seguridad. Se usa Node.js 22 (LTS) en su variante Alpine por ser ligera y adecuada para producción. La versión puede cambiarse al construir:

```bash
docker build --build-arg NODE_VERSION=24-alpine -t nextjs-docker-app .
```

### ¿Por qué `node server.js` en lugar de `next start`?

Con `output: "standalone"`, `next build` genera un `server.js` mínimo que es el servidor de producción de Next.js, equivalente a `next start`, pero sin necesitar todo `node_modules`. Next.js no admite `next start` con la salida standalone, por eso el `CMD` del Dockerfile es `node server.js`. Este servidor respeta las variables `PORT` y `HOSTNAME` (definidas como `3000` y `0.0.0.0` para aceptar conexiones desde fuera del contenedor).

## 🙈 `.dockerignore`

Evita enviar al contexto de build archivos innecesarios o sensibles, lo que acelera el build y mantiene la imagen limpia:

| Excluido                                   | Motivo                                                       |
| ------------------------------------------ | ------------------------------------------------------------ |
| `node_modules`                             | Se instalan dentro de la imagen con `npm ci`.                |
| `.next`, `out`, `build`, `coverage`        | Se generan dentro de la imagen con `next build`.             |
| `.env`, `.env.*`, `*.pem`                  | Secretos: nunca deben quedar dentro de la imagen.            |
| `.git`, `.gitignore`                       | Historial de versiones, no se necesita para ejecutar.        |
| `*.log`, `*.tmp`, `tmp`, `*.tsbuildinfo`   | Archivos temporales y de depuración.                         |
| `.vscode`, `.idea`, `.DS_Store`            | Configuración de editores y del sistema operativo.           |
| `Dockerfile`, `README.md`, `docs`          | No son necesarios dentro de la imagen.                       |

## 💻 Desarrollo local (sin Docker)

```bash
npm install
npm run dev      # http://localhost:3000
npm run build    # build de producción
npm run lint
```

## 📁 Estructura del proyecto

```
.
├── Dockerfile          # Build multi-stage de la imagen
├── .dockerignore       # Archivos excluidos del contexto de build
├── next.config.ts      # output: "standalone"
├── package.json
├── public/             # Archivos estáticos
└── src/app/            # Páginas (App Router)
```
