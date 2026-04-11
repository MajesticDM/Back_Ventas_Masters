# DIAN Electronic Invoicing — Implementation Guide

Integration of VentasMasters with Colombia's DIAN for electronic invoicing
(**Factura Electrónica de Venta**) via the *Software Propio* model (direct integration,
no third-party provider).

---

## Assumptions

The following are assumed to be already in place before any phase is run:

| Item | Description |
|------|-------------|
| Digital certificate | `.p12` file issued by a DIAN-accredited CA (e.g. Certicámara, GSE) |
| DIAN resolution | `NUMERO_RESOLUCION`, prefix, number range, validity dates, and `CLAVE_TECNICA` |
| Software registration | `SOFTWARE_ID` and `SOFTWARE_PIN` from the DIAN portal |
| Test environment | DIAN habilitación environment accessible (`AMBIENTE_DIAN = 2`) |

---

## Phase Overview

| Phase | Scope | Status |
|-------|-------|--------|
| **0** | Database schema | ✅ Complete |
| **1** | UBL 2.1 XML generation + CUFE calculation | 🔲 Pending |
| **2** | XAdES-B-BES digital signature | 🔲 Pending |
| **3** | DIAN transmission + response handling | 🔲 Pending |
| **4** | Frontend — DIAN status, QR, configuration UI | 🔲 Pending |
| **5** | Credit Notes and Debit Notes | 🔲 Pending |

---

## Phase 0 — Database Schema ✅

**File:** `sp_dian_fase0.sql`
**Execution order:** `sp_anulacion.sql` → `sp_dian_fase0.sql`

### New Tables

#### `RESOLUCIONES_DIAN`
Stores one row per DIAN resolution (usually one active FC resolution at a time).

| Column | Type | Description |
|--------|------|-------------|
| `ID_RESOLUCION` | NUMERIC IDENTITY | PK |
| `NUMERO_RESOLUCION` | VARCHAR(20) | e.g. `18764030000001` |
| `FECHA_RESOLUCION` | DATE | Resolution issue date |
| `FECHA_INICIO_VIGENCIA` | DATE | Start of validity |
| `FECHA_FIN_VIGENCIA` | DATE | End of validity |
| `PREFIJO` | VARCHAR(10) | Invoice prefix, e.g. `SETT` (nullable) |
| `RANGO_INICIO` | NUMERIC | First allowed number |
| `RANGO_FIN` | NUMERIC | Last allowed number |
| `NUMERO_ACTUAL` | NUMERIC | Current counter (auto-incremented atomically) |
| `CLAVE_TECNICA` | VARCHAR(200) | Technical key for CUFE hashing |
| `TIPO` | VARCHAR(2) | `FC` = invoice, `NC` = credit note, `ND` = debit note |
| `ACTIVA` | BIT | Only one active resolution per type |

#### `TIPOS_IVA`
Catalog of tax types used on invoice lines.

| ID | Description | % | DIAN code |
|----|-------------|---|-----------|
| 1 | IVA 19% | 19.00 | 01 |
| 2 | IVA 5% | 5.00 | 01 |
| 3 | Exento | 0.00 | 01 |
| 4 | Excluido | 0.00 | ZZ |

### Columns Added to Existing Tables

**`FACTURAS`**
- `NUMERO_FACTURA_DIAN` — consecutive from the resolution range
- `ESTADO_DIAN` — `PENDIENTE` | `VALIDADA` | `RECHAZADA` | `CONTINGENCIA` | `ANULADA`
- `FECHA_VALIDACION_DIAN` — timestamp of DIAN acceptance
- `QR_DIAN` — QR URL returned by DIAN
- `XML_DIAN` — the signed UBL 2.1 XML
- `NOTAS_DIAN` — rejection messages from DIAN

**`CONFIGURACIONES`** (single-row company settings)
- `NOMBRE_COMERCIAL`, `DIGITO_VERIFICACION`
- `MUNICIPIO_DIAN`, `DEPARTAMENTO_DIAN`, `CODIGO_POSTAL` (DANE codes)
- `IDX_TIPO_DOCUMENTO_EMPRESA`, `IDX_REGIMEN_TRIBUTARIO_EMPRESA`, `IDX_RESPONSABILIDAD_FISCAL_EMPRESA`
- `SOFTWARE_ID_DIAN`, `SOFTWARE_PIN_DIAN`
- `AMBIENTE_DIAN` — `1` = production, `2` = habilitación

**`PRODUCTOS`**
- `CODIGO_UNSPSC` — UN commodity code (e.g. `25172000` for motorcycle parts)
- `IDX_TIPO_IVA` — FK to `TIPOS_IVA`

**`CLIENTES`**
- `MUNICIPIO_DIAN`, `CODIGO_POSTAL`

**`FORMAS_PAGO`**
- `CODIGO_MEDIO_PAGO_DIAN` — DIAN payment means code (`10`=cash, `30`=credit, `42`=transfer, `48`=credit card, `49`=debit card, `ZZZ`=other)

### New Stored Procedures

#### `SP_DIAN_SIGUIENTE_NUMERO`
Atomically increments the resolution counter using `UPDATE ... OUTPUT`.
Returns `NULL` if no active resolution exists or the range is exhausted.
Called internally by `SP_FACTURAS_ACCIONES` on every `crearFactura`.

#### `SP_DIAN_ACTUALIZAR_ESTADO`
Persists DIAN processing results back to the invoice row.
Called from the C# backend at two points:
1. After XML is signed → saves `XML_DIAN`, `CUFE_FACTURA`
2. After DIAN responds → saves `ESTADO_DIAN`, `QR_DIAN`, `NOTAS_DIAN`

#### `SP_DIAN_DATOS_FACTURA`
Returns the full payload needed to build the UBL 2.1 XML document (4 result sets):

| Table | Content |
|-------|---------|
| `tables[0]` | 1 row — invoice header, issuer data, acquirer data, active resolution, payment method |
| `tables[1]` | Product lines with UNSPSC, unit price, IVA breakdown |
| `tables[2]` | Service lines |
| `tables[3]` | Tax subtotals grouped by IVA type (for `TaxTotal` element in UBL) |

#### Modified: `SP_FACTURAS_ACCIONES`
`crearFactura` now assigns `NUMERO_FACTURA_DIAN` from the active resolution and sets `ESTADO_DIAN = 'PENDIENTE'` on every new invoice.
Also integrates the `anularFactura` action from `sp_anulacion.sql` (sets `ESTADO_DIAN = 'ANULADA'`).

#### Modified: `SP_CARGADO_FACTURAS`
`tables[0]` now includes `CUFE_FACTURA`, `NUMERO_FACTURA_DIAN`, `ESTADO_DIAN`, `QR_DIAN`.

---

## Phase 1 — UBL 2.1 XML + CUFE 🔲

**Scope:** C# service that reads from `SP_DIAN_DATOS_FACTURA` and produces a valid UBL 2.1 `Invoice` document, then computes and stores the CUFE.

### CUFE Formula (SHA-384)

```
CUFE = SHA384(
  NumFac   + FecFac   + HorFac   +
  ValFac   + CodImp1  + ValImp1  +
  ValImp2  + ValImp3  + ValTot   +
  NitOFE   + TipDocAdq + NumDocAdq +
  ClTec    + TipoAmb
)
```

| Token | Source in DB |
|-------|-------------|
| `NumFac` | `NUMERO_FACTURA_DIAN` |
| `FecFac` | `fecha_dian` from SP (format `yyyyMMdd`) |
| `HorFac` | `hora_dian` from SP (format `HH:mm:ss-05:00`) |
| `ValFac` | `subtotal` (COSTO_TOTAL − VALOR_IVA) |
| `CodImp1` | `01` (IVA) |
| `ValImp1` | `total_iva` |
| `ValImp2` | `0` (INC — not applicable) |
| `ValImp3` | `0` (ICA — not applicable) |
| `ValTot` | `total` (COSTO_TOTAL) |
| `NitOFE` | `emisor_nit` |
| `TipDocAdq` | `adquirente_tipo_documento` |
| `NumDocAdq` | `adquirente_identificacion` |
| `ClTec` | `clave_tecnica` from resolution |
| `TipoAmb` | `ambiente_dian` as string |

### Tasks

- [ ] Create `DianXmlService` in `CORE.MMms` (or a dedicated `DIAN.MMms` project)
- [ ] Map `SP_DIAN_DATOS_FACTURA` result sets to C# DTOs
- [ ] Build UBL 2.1 `Invoice` XML using `System.Xml` or a template engine
- [ ] Implement CUFE SHA-384 calculation
- [ ] Call `SP_DIAN_ACTUALIZAR_ESTADO` to persist XML and CUFE
- [ ] Add endpoint: `POST api/Dian/GenerarXml/{idFactura}`

---

## Phase 2 — XAdES-B-BES Digital Signature 🔲

**Scope:** Sign the UBL XML produced in Phase 1 with the company's `.p12` certificate
using the XAdES-B-BES profile required by DIAN.

### Key Points

- Algorithm: `RSA-SHA256` (signature) + `SHA-256` (digest)
- Transform: `http://www.w3.org/2001/10/xml-exc-c14n#` (exclusive canonicalization)
- The `<ds:Signature>` element is embedded inside `<ext:UBLExtensions>`
- Certificate must be loaded from the `.p12` file using `X509Certificate2`

### Tasks

- [ ] Store `.p12` path and password in `appsettings.json` (or environment variable — do **not** commit the certificate)
- [ ] Implement `XadesSignerService` using `System.Security.Cryptography.Xml`
- [ ] Embed the signature in the UBL XML
- [ ] Validate the signature locally before transmission
- [ ] Update `SP_DIAN_ACTUALIZAR_ESTADO` call to persist the signed XML

---

## Phase 3 — DIAN Transmission + Response Handling 🔲

**Scope:** Send the signed XML to the DIAN web service, parse the response,
and update the invoice status accordingly.

### DIAN Endpoints

| Environment | URL |
|-------------|-----|
| Habilitación | `https://vpfe-hab.dian.gov.co/WcfDianCustomerServices.svc` |
| Producción | `https://vpfe.dian.gov.co/WcfDianCustomerServices.svc` |

The DIAN service uses **SOAP** (`GetStatus`, `SendBillAsync`, `GetXmlByDocumentKey`).

### Tasks

- [ ] Implement `DianTransmissionService` (SOAP client wrapping DIAN WSDL)
- [ ] `SendBillAsync` — sends the signed XML as a Base64 ZIP package
- [ ] `GetStatus` — polls for processing result (DIAN may respond asynchronously)
- [ ] Parse `IsValid`, `StatusCode`, `StatusDescription`, `QRStr` from response
- [ ] Map status codes to `ESTADO_DIAN` values and call `SP_DIAN_ACTUALIZAR_ESTADO`
- [ ] Add endpoint: `POST api/Dian/EnviarFactura/{idFactura}`
- [ ] Implement retry logic for temporary DIAN failures (HTTP 500, timeouts)
- [ ] Handle contingency mode (store locally, send when service recovers)

---

## Phase 4 — Frontend 🔲

**Scope:** Surface DIAN status information to the user and provide a configuration UI.

### Invoice Detail (`factura.component`)

- [ ] Show DIAN status badge next to invoice number
  - `PENDIENTE` — gray
  - `VALIDADA` — green ✓
  - `RECHAZADA` — red ✗
  - `CONTINGENCIA` — orange
- [ ] Show QR code when `ESTADO_DIAN = 'VALIDADA'` (render `QR_DIAN` URL)
- [ ] Show rejection notes (`NOTAS_DIAN`) when status is `RECHAZADA`
- [ ] "Enviar a DIAN" button (calls `POST api/Dian/EnviarFactura/{id}`) — hidden when already `VALIDADA`

### Invoice List (`finanzas.component`)

- [ ] Add DIAN status column/indicator to invoice cards
- [ ] Add "Pendientes DIAN" filter checkbox

### Configuration UI (new page or settings section)

- [ ] Form to fill DIAN company fields (`MUNICIPIO_DIAN`, `SOFTWARE_ID_DIAN`, etc.)
- [ ] Form to register a new `RESOLUCIONES_DIAN` row
- [ ] Display current resolution progress (counter vs. range)
- [ ] Update `CODIGO_UNSPSC` and `IDX_TIPO_IVA` per product (in product edit form)
- [ ] Update `CODIGO_MEDIO_PAGO_DIAN` per payment method (in settings)
- [ ] Update `MUNICIPIO_DIAN` / `CODIGO_POSTAL` per client (in client edit form)

---

## Phase 5 — Credit Notes and Debit Notes 🔲

**Scope:** Issue DIAN-compliant `CreditNote` and `DebitNote` UBL documents,
linked to the original invoice. Triggered from the invoice cancellation flow.

### Key Differences from FC

| Field | Credit Note | Debit Note |
|-------|-------------|------------|
| UBL root element | `CreditNote` | `DebitNote` |
| DIAN document type | `NC` | `ND` |
| Resolution type | `NC` in `RESOLUCIONES_DIAN` | `ND` in `RESOLUCIONES_DIAN` |
| Requires reference to | Original `CUFE_FACTURA` | Original `CUFE_FACTURA` |

### Tasks

- [ ] Add `NOTAS_CREDITO` and `NOTAS_DEBITO` tables (or extend `FACTURAS` with a `TIPO_DOCUMENTO` column and `IDX_FACTURA_ORIGINAL`)
- [ ] Add `NC` and `ND` resolutions to `RESOLUCIONES_DIAN`
- [ ] Extend `SP_DIAN_DATOS_FACTURA` to support NC/ND
- [ ] Implement XML builders for `CreditNote` and `DebitNote`
- [ ] Connect credit note generation to the `anularFactura` flow (optional — a manual cancellation with DIAN NC is separate from the internal `ANULADO` flag)
- [ ] Frontend: "Generar Nota Crédito" button on validated invoices

---

## File Map

```
Back_Ventas_Masters/
├── sp_anulacion.sql          — Invoice cancellation (prerequisite for fase 0)
├── sp_dian_fase0.sql         — DIAN Phase 0: schema + seed + SPs
├── sp_balance_diario.sql     — SP_BALANCE_DIARIO_IMPRIMIBLE (updated: excludes ANULADO)
├── nuevos_sps.sql            — Analytics SPs (updated: excludes ANULADO)
├── Crear_bd_carlos.sql       — Original DB creation script (read-only reference)
└── README_DIAN.md            — This file
```

## Execution Order

```sql
-- 1. Verify ANULADO column exists
SELECT TOP 1 ANULADO FROM FACTURAS;
-- If error: ALTER TABLE FACTURAS ADD ANULADO BIT NULL DEFAULT 0;

-- 2. Run cancellation changes
-- sp_anulacion.sql

-- 3. Run DIAN Phase 0
-- sp_dian_fase0.sql

-- 4. Populate company DIAN data (run once, adapt values)
UPDATE CONFIGURACIONES SET
    NOMBRE_COMERCIAL                    = 'MOTO MASTERS',
    DIGITO_VERIFICACION                 = '0',          -- calculate for your NIT
    MUNICIPIO_DIAN                      = '11001',      -- DANE code
    DEPARTAMENTO_DIAN                   = '11',
    CODIGO_POSTAL                       = '110111',
    IDX_TIPO_DOCUMENTO_EMPRESA          = (SELECT ID_TIPO_DOCUMENTO FROM TIPO_DOCUMENTO WHERE EQUIVALENCIA_TIPO = '31'),
    IDX_REGIMEN_TRIBUTARIO_EMPRESA      = (SELECT TOP 1 ID_REGIMEN_TRIBUTARIO FROM REGIMENES_TRIBUTARIOS WHERE EQUIVALENCIA_REGIMEN_TRIBUTARIO = 'ZZ'),
    IDX_RESPONSABILIDAD_FISCAL_EMPRESA  = (SELECT TOP 1 ID_RESPONSABILIDAD_FISCAL FROM RESPONSABILIDADES_FISCALES WHERE EQUIVALENCIA_RESPONSABILIDAD = 'O-13'),
    SOFTWARE_ID_DIAN                    = '<your-software-id>',
    SOFTWARE_PIN_DIAN                   = '<your-software-pin>',
    AMBIENTE_DIAN                       = 2;            -- 2 = habilitación, 1 = producción

-- 5. Register active resolution
INSERT INTO RESOLUCIONES_DIAN (
    NUMERO_RESOLUCION, FECHA_RESOLUCION,
    FECHA_INICIO_VIGENCIA, FECHA_FIN_VIGENCIA,
    PREFIJO, RANGO_INICIO, RANGO_FIN, NUMERO_ACTUAL,
    CLAVE_TECNICA, TIPO, ACTIVA
) VALUES (
    '18764030000001', '2024-01-15',
    '2024-01-15',     '2025-01-15',
    'SETT', 1, 5000000, 0,
    '<clave-tecnica-from-dian>', 'FC', 1
);

-- 6. Set UNSPSC defaults on existing products (adjust per product category)
UPDATE PRODUCTOS SET CODIGO_UNSPSC = '25172000', IDX_TIPO_IVA = 1
WHERE IDX_TIPO_IVA IS NULL;   -- 1 = IVA 19% from TIPOS_IVA

-- 7. Set DIAN payment codes on FORMAS_PAGO (adjust IDs to match your data)
UPDATE FORMAS_PAGO SET CODIGO_MEDIO_PAGO_DIAN = '10'  WHERE MANEJA_CREDITO = 0; -- efectivo
UPDATE FORMAS_PAGO SET CODIGO_MEDIO_PAGO_DIAN = '30'  WHERE MANEJA_CREDITO = 1; -- crédito
```
