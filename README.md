# Oficina JZG — Arriendo de box por hora/jornada

Plataforma Rails 8 para arrendar boxes clínicos y sala de reuniones en un único local. Fork adaptado de rentabox.

## Stack

Rails 8, Hotwire, Tailwind CSS, PostgreSQL, Redis, Sidekiq, Devise, Pundit, Mercado Pago.

## Inicio rápido

```bash
docker compose up db redis -d
bundle install
bin/rails db:prepare db:seed
bin/dev
```

PostgreSQL del proyecto se expone en el host en el puerto **5433** (5432 suele estar ocupado por otros contenedores). Rails en local usa ese puerto por defecto; dentro de Docker Compose se conecta al servicio `db` en el puerto interno 5432.

## Usuarios demo (seeds)

| Rol | Email | Contraseña |
|-----|-------|------------|
| Admin | admin@jzg.cl | password123 |
| Profesional | profesional@jzg.cl | password123 |

## Funcionalidades

- Homepage estilo workspace con salas, valores, testimonios, FAQ y mapa
- Reserva por hora (default) o por jornada
- Roles: admin, profesional, profesional_suscrito
- Validación Superintendencia (API + manual en admin)
- Motor de precios configurable (descuentos por volumen y membresía)
- Mercado Pago + boletas electrónicas (DTE 39) vía LibreDTE con email y PDF adjunto
- Membresía con beneficios
- Reagendamiento con créditos (sin reembolso)
- Testimonios moderables
- Google Analytics 4

## Variables de entorno

Ver `.env.example`.

### Boletas (LibreDTE)

Tras un pago aprobado, `GenerateInvoiceJob` emite boleta tipo 39 en tres pasos (temporal → real → PDF) y envía el PDF por email al profesional.

| Variable | Descripción |
|----------|-------------|
| `LIBREDTE_API_URL` | Base API (default `https://libredte.cl/api`) |
| `LIBREDTE_API_TOKEN` | Hash de autenticación LibreDTE |
| `LIBREDTE_EMISOR_RUT` | RUT de la empresa emisora (JZG) |
| `LIBREDTE_STUB` | `true` en dev/test: emite boleta simulada sin llamar a la API |
| `MAILER_FROM` | Remitente de emails (dev: letter_opener; prod: SMTP) |

## Panel admin

`/admin` — oficina, espacios, jornadas, reglas de precio, profesionales, reservas, membresías, testimonios, FAQ y configuración.
