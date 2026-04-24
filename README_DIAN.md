# DIAN Electronic Invoicing — Implementation Guide

Integration of VentasMasters with Colombia's DIAN for electronic invoicing
(**Factura Electrónica de Venta**) via the *Software Propio* model (direct integration,
no third-party provider).

Spec reference: **Anexo Técnico Factura Electrónica de Venta v1.9**
(Resolución 000165 del 1 de noviembre de 2023, mandatory from May 1, 2024).

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
| **1** | UBL 2.1 XML generation + CUFE calculation | ✅ Complete |
| **2** | XAdES-B-BES digital signature | ✅ Complete |
| **3** | DIAN transmission + response handling | ✅ Complete |
| **4** | Frontend — DIAN status, QR, configuration UI | ✅ Complete |
| **5** | Credit Notes and Debit Notes | 🔲 Pending |

---

## Phase 0 — Database Schema ✅

**Files:** `sp_anulacion.sql` → `sp_dian_fase0.sql` → `sp_dian_fase1_fixes.sql`

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

**`FACTURAS`** *(sp_dian_fase0.sql)*
> Note: `CUFE_FACTURA VARCHAR(1000)` already existed in the original schema (`CREAR_ESTRUCTURA.sql`).
> Phase 0 only adds the columns below.

- `NUMERO_FACTURA_DIAN` — consecutive from the resolution range
- `ESTADO_DIAN` — `PENDIENTE` | `VALIDADA` | `RECHAZADA` | `CONTINGENCIA` | `ANULADA`
- `FECHA_VALIDACION_DIAN` — timestamp of DIAN acceptance
- `QR_DIAN` — QR URL returned by DIAN
- `XML_DIAN` — the signed UBL 2.1 XML
- `NOTAS_DIAN` — rejection messages from DIAN

**`FACTURAS`** *(sp_dian_fase1_fixes.sql)*
- `FECHA_VENCIMIENTO` — explicit due date for credit invoices; if NULL the SP derives it as `FECHA_VENTA + 30 days` for credit or `FECHA_VENTA` for cash

**`CONFIGURACIONES`** *(sp_dian_fase0.sql — single-row company settings)*
- `NOMBRE_COMERCIAL`, `DIGITO_VERIFICACION`
- `MUNICIPIO_DIAN`, `DEPARTAMENTO_DIAN`, `CODIGO_POSTAL` (DANE codes)
- `IDX_TIPO_DOCUMENTO_EMPRESA`, `IDX_REGIMEN_TRIBUTARIO_EMPRESA`, `IDX_RESPONSABILIDAD_FISCAL_EMPRESA`
- `SOFTWARE_ID_DIAN`, `SOFTWARE_PIN_DIAN`
- `AMBIENTE_DIAN` — `1` = production, `2` = habilitación

**`PRODUCTOS`** *(sp_dian_fase0.sql)*
- `CODIGO_UNSPSC` — UN commodity code (e.g. `25172000` for motorcycle parts)
- `IDX_TIPO_IVA` — FK to `TIPOS_IVA`

**`CLIENTES`** *(sp_dian_fase0.sql)*
- `MUNICIPIO_DIAN`, `CODIGO_POSTAL`

**`CLIENTES`** *(sp_dian_fase1_fixes.sql)*
- `DIGITO_VERIFICACION` — NIT verification digit; used as `CompanyID/@schemeID` in UBL for business clients; leave NULL for natural persons (CC/CE → defaults to `"0"`)

**`FORMAS_PAGO`** *(sp_dian_fase0.sql)*
- `CODIGO_MEDIO_PAGO_DIAN` — DIAN payment means code (`10`=cash, `30`=credit, `42`=transfer, `48`=credit card, `49`=debit card, `ZZZ`=other)

### Stored Procedures

#### `SP_DIAN_SIGUIENTE_NUMERO`
Atomically increments the resolution counter using `UPDATE ... OUTPUT`.
Returns `NULL` if no active resolution exists or the range is exhausted.
Called internally by `SP_FACTURAS_ACCIONES` on every `crearFactura`.

#### `SP_DIAN_ACTUALIZAR_ESTADO`
Persists DIAN processing results back to the invoice row.
Called from the C# backend at two points:
1. After XML is generated and signed → saves `XML_DIAN`, `CUFE_FACTURA`
2. After DIAN responds → saves `ESTADO_DIAN`, `QR_DIAN`, `NOTAS_DIAN`

Parameters: `@id_factura`, `@cufe`, `@estado_dian`, `@qr_dian`, `@xml_dian`, `@notas_dian`
(all nullable — only non-null values are updated via `ISNULL()`).

#### `SP_DIAN_DATOS_FACTURA`
Returns the full payload needed to build the UBL 2.1 XML document (4 result sets).
Last updated in `sp_dian_fase1_fixes.sql`.

| Table | Content |
|-------|---------|
| `tables[0]` | 1 row — invoice header, issuer, acquirer, active resolution, payment method |
| `tables[1]` | Product lines with UNSPSC, unit price, IVA breakdown |
| `tables[2]` | Service lines |
| `tables[3]` | Tax subtotals grouped by IVA type (for `TaxTotal` in UBL) |

Key columns in `tables[0]`:

| Column | Notes |
|--------|-------|
| `fecha_dian` | `yyyyMMdd` — used in CUFE |
| `hora_dian` | `HH:mm:ss-05:00` — used in CUFE |
| `subtotal` | `COSTO_TOTAL − VALOR_IVA` — `ValFac` in CUFE |
| `total_iva` | `ValImp1` in CUFE |
| `total` | `COSTO_TOTAL` — `ValTot` in CUFE |
| `fecha_vencimiento_dian` | Explicit `FECHA_VENCIMIENTO` or derived (+30d credit / same day cash) |
| `maneja_credito` | From `FORMAS_PAGO.MANEJA_CREDITO` |
| `prepago` | `FACTURAS.PAGO_INICIAL` — drives `PrepaidPayment` in XML |
| `adquirente_digito_verificacion` | `CLIENTES.DIGITO_VERIFICACION` — `CompanyID/@schemeID` |
| `tipo_pago_dian` | `'Crédito'` or `'Contado'` — derived from `FP.MANEJA_CREDITO` |

#### Modified: `SP_FACTURAS_ACCIONES`
`crearFactura` now assigns `NUMERO_FACTURA_DIAN` from the active resolution and sets `ESTADO_DIAN = 'PENDIENTE'` on every new invoice.
Also integrates the `anularFactura` action (sets `ESTADO_DIAN = 'ANULADA'`).

#### Modified: `SP_CARGADO_FACTURAS`
`tables[0]` now includes `CUFE_FACTURA`, `NUMERO_FACTURA_DIAN`, `ESTADO_DIAN`, `QR_DIAN`.

---

## Phase 1 — UBL 2.1 XML + CUFE ✅

**Scope:** C# service that reads from `SP_DIAN_DATOS_FACTURA` and produces a valid
UBL 2.1 `Invoice` document compliant with Anexo Técnico v1.9, then computes and
stores the CUFE.

### CUFE Formula (SHA-384)

Per Anexo Técnico v1.9, the concatenation is:

```
CUFE = SHA384(
  NumFac + FecFac + HorFac +
  ValFac + CodImp1 + ValImp1 +
  CodImp2 + ValImp2 +
  CodImp3 + ValImp3 +
  ValTot + NitOFE + TipDocAdq + NumDocAdq +
  ClTec + TipoAmb
)
```

| Token | Value / Source |
|-------|---------------|
| `NumFac` | `prefijo_dian` + `NUMERO_FACTURA_DIAN` |
| `FecFac` | `fecha_dian` — format `yyyyMMdd` |
| `HorFac` | `hora_dian` — format `HH:mm:ss-05:00` |
| `ValFac` | `subtotal` (`COSTO_TOTAL − VALOR_IVA`) |
| `CodImp1` | `"01"` (IVA) |
| `ValImp1` | `total_iva` |
| `CodImp2` | `"04"` (INC) — **always present even when zero** |
| `ValImp2` | `"0.00"` (INC not applicable) |
| `CodImp3` | `"03"` (ICA) — **always present even when zero** |
| `ValImp3` | `"0.00"` (ICA not applicable) |
| `ValTot` | `total` (`COSTO_TOTAL`) |
| `NitOFE` | `emisor_nit` |
| `TipDocAdq` | `adquirente_tipo_documento` |
| `NumDocAdq` | `adquirente_identificacion` |
| `ClTec` | `clave_tecnica` from resolution |
| `TipoAmb` | `ambiente_dian` as string (`"1"` or `"2"`) |

All monetary values formatted with exactly 2 decimal places, dot separator, invariant culture.

### C# Files

| File | Layer | Purpose |
|------|-------|---------|
| `CORE.MMms/DTOs/DianDTOs.cs` | CORE | `DianGenerarXmlResultDto`, `DianActualizarEstadoDto` |
| `CORE.MMms/Interfaces/IDian.cs` | CORE | Repo contract: `GetDatosFactura`, `ActualizarEstado` |
| `CORE.MMms/Interfaces/IDianXmlService.cs` | CORE | Service contract: `GenerarXml` |
| `INFRA.MMms/Repository/DianRepo.cs` | INFRA | ADO.NET calls to `SP_DIAN_DATOS_FACTURA` and `SP_DIAN_ACTUALIZAR_ESTADO` |
| `INFRA.MMms/Services/DianXmlService.cs` | INFRA | UBL 2.1 XML builder (XDocument) + SHA-384 CUFE + calls Phase 2 signer |
| `API.MMms/Controllers/DianController.cs` | API | `POST api/Dian/GenerarXml/{idFactura}` |
| `API.MMms/Resolvers/MotoMasters_Dependencies.cs` | API | DI registrations |

### UBL 2.1 Structure Generated

```
Invoice
├── ext:UBLExtensions / ExtensionContent      ← Phase 2 XAdES-B-BES signature
├── cbc:UBLVersionID = "UBL 2.1"
├── cbc:CustomizationID = "10"
├── cbc:ProfileID = "DIAN 2.1"
├── cbc:ProfileExecutionID = ambiente_dian
├── cbc:ID = prefix + NUMERO_FACTURA_DIAN
├── cbc:UUID (schemeID=ambiente, schemeName="CUFE-SHA384") = cufe
├── cbc:IssueDate / cbc:IssueTime
├── cbc:InvoiceTypeCode = "01"
├── cbc:Note = "CUFE: ..."
├── cbc:DocumentCurrencyCode = "COP"
├── cbc:LineCountNumeric
├── cac:InvoicePeriod (StartDate + EndDate = IssueDate)
├── cac:AdditionalDocumentReference         ← DIAN resolution (DocumentTypeCode="09")
├── cac:AccountingSupplierParty             ← emisor: NIT + DV, regime, tax scheme
├── cac:AccountingCustomerParty             ← adquirente: ID + DV, tipo doc, regime
├── cac:PaymentMeans (DueDate = fecha_vencimiento_dian)
├── cac:PrepaidPayment                      ← only when PAGO_INICIAL > 0
├── cac:TaxTotal + TaxSubtotal × IVA type  ← from tables[3]
├── cac:LegalMonetaryTotal
│   ├── LineExtensionAmount / TaxExclusiveAmount / TaxInclusiveAmount
│   ├── PrepaidAmount                       ← only when PAGO_INICIAL > 0
│   └── PayableAmount = total − prepago
└── cac:InvoiceLine × N                    ← products (tables[1]) + services (tables[2])
    ├── InvoicedQuantity (unitCode)
    ├── LineExtensionAmount
    ├── TaxTotal + TaxSubtotal
    ├── Item / Description + UNSPSC (StandardItemIdentification)
    └── Price / PriceAmount
```

---

## Phase 2 — XAdES-B-BES Digital Signature ✅

**Scope:** Sign the UBL XML produced in Phase 1 with the company's `.p12` certificate
using the XAdES-B-BES profile required by DIAN.

### Signature Algorithms

| Aspect | Algorithm / Value |
|--------|-------------------|
| Signature | `RSA-SHA256` (`http://www.w3.org/2001/09/xmldsig-more#rsa-sha256`) |
| Digest | `SHA-256` (`http://www.w3.org/2001/04/xmlenc#sha256`) |
| Canonicalization | Exclusive C14N (`http://www.w3.org/2001/10/xml-exc-c14n#`) |
| Certificate | X.509 from `.p12` file, loaded via `X509Certificate2` |

### Three `ds:Reference` Elements (per Anexo Técnico v1.9)

| # | URI | Type | Transforms | Description |
|---|-----|------|------------|-------------|
| 0 | `""` | — | enveloped-signature → exc-c14n | Entire invoice document |
| 1 | `#keyinfo-id` | — | exc-c14n | `ds:KeyInfo` element |
| 2 | `#signedprops-id` | `http://uri.etsi.org/01903#SignedProperties` | exc-c14n | XAdES `SignedProperties` |

### Signature Element Location

```xml
<ext:UBLExtensions>
  <ext:UBLExtension>
    <ext:ExtensionContent>
      <ds:Signature Id="xmldsig-{uuid}">
        <ds:SignedInfo> ... </ds:SignedInfo>
        <ds:SignatureValue Id="xmldsig-{uuid}-sigvalue"> ... </ds:SignatureValue>
        <ds:KeyInfo Id="xmldsig-{uuid}-keyinfo">
          <ds:X509Data><ds:X509Certificate>...</ds:X509Certificate></ds:X509Data>
        </ds:KeyInfo>
        <ds:Object Id="xmldsig-{uuid}-object0">
          <xades:QualifyingProperties Target="#xmldsig-{uuid}">
            <xades:SignedProperties Id="xmldsig-{uuid}-signedprops">
              <xades:SignedSignatureProperties>
                <xades:SigningTime>...</xades:SigningTime>
                <xades:SigningCertificate>
                  <xades:Cert>
                    <xades:CertDigest>
                      <ds:DigestMethod Algorithm="...sha256"/>
                      <ds:DigestValue><!-- SHA-256 of DER cert --></ds:DigestValue>
                    </xades:CertDigest>
                    <xades:IssuerSerial>
                      <ds:X509IssuerName>...</ds:X509IssuerName>
                      <ds:X509SerialNumber>...</ds:X509SerialNumber>
                    </xades:IssuerSerial>
                  </xades:Cert>
                </xades:SigningCertificate>
              </xades:SignedSignatureProperties>
            </xades:SignedProperties>
          </xades:QualifyingProperties>
        </ds:Object>
      </ds:Signature>
    </ext:ExtensionContent>
  </ext:UBLExtension>
</ext:UBLExtensions>
```

### Signing Process (two-pass approach)

1. Build full `ds:Signature` structure with placeholder digest values and empty `ds:SignatureValue`, embed it in `ext:ExtensionContent`.
2. Compute all three SHA-256 digests **from within the assembled document** so that exclusive c14n uses correct inherited namespace context.
3. Patch the three `ds:DigestValue` elements in the DOM.
4. Select `ds:SignedInfo` in context, apply exc-c14n to get the canonical bytes.
5. Sign with RSA-SHA256 using the private key from the `.p12`.
6. Write the Base64 `ds:SignatureValue`.
7. Validate locally with a `SignedXml` subclass that resolves IDs inside `ds:Object` data objects.

### C# Files

| File | Layer | Purpose |
|------|-------|---------|
| `CORE.MMms/Interfaces/IXadesSignerService.cs` | CORE | Service contract: `FirmarXml`, `ValidarFirma` |
| `INFRA.MMms/Services/XadesSignerService.cs` | INFRA | Full XAdES-B-BES implementation |

### NuGet Package Added

`System.Security.Cryptography.Xml` **8.0.1** → `INFRA.MMms.csproj`

Provides: `SignedXml`, `XmlDsigExcC14NTransform`, `XmlDsigEnvelopedSignatureTransform`,
`KeyInfo`, `KeyInfoX509Data`.

### Configuration

Add to `API.MMms/appsettings.json` (or override via environment variable):

```json
"Dian": {
  "CertificadoRuta": "/ruta/al/certificado.p12",
  "CertificadoClave": "contraseña-del-certificado"
}
```

> **Security:** Never commit the `.p12` file or its password to source control.
> Use environment variables or a secrets manager in production.
> Add `*.p12` to `.gitignore`.

### DI Registration Order

```csharp
services.AddTransient<IDian,              DianRepo>();
services.AddTransient<IXadesSignerService, XadesSignerService>();  // Phase 2
services.AddTransient<IDianXmlService,    DianXmlService>();        // depends on both above
```

---

## Phase 3 — DIAN Transmission + Response Handling ✅

**Scope:** Package the signed XML as a ZIP, transmit to the DIAN SOAP service,
poll for a validation result, and persist the final status to the invoice.

### DIAN Endpoints

| Environment | URL |
|-------------|-----|
| Habilitación | `https://vpfe-hab.dian.gov.co/WcfDianCustomerServices.svc` |
| Producción | `https://vpfe.dian.gov.co/WcfDianCustomerServices.svc` |

DIAN uses SOAP 1.1 with WS-Security UsernameToken (non-standard variant — WCF generated clients won't work).
The correct endpoint is selected automatically from `CONFIGURACIONES.AMBIENTE_DIAN`.

### WS-Security Token Formula

```
Password = BASE64( SHA-384( SoftwareId + SoftwarePin + Key ) )
```

- For `SendBillAsync`: `Key = ZipKey` (e.g. `SETT000001`, no `.zip` extension)
- For `GetStatus`: `Key = TrackId` (the UUID returned by DIAN)
- Nonce: 16 random bytes, Base64-encoded
- `Created`: UTC timestamp `yyyy-MM-ddTHH:mm:ss.fffZ`

### Transmission Flow

```
POST /api/Dian/EnviarFactura/{idFactura}
        │
        ▼
DianController.EnviarFactura
        │
        ▼
DianTransmissionService.EnviarFacturaAsync
  ├─ DianRepo.GetXmlPendiente           → SP_DIAN_OBTENER_XML
  │    (XmlFirmado, ZipKey, TrackId, AmbienteDian)
  ├─ BuildZip(zipKey+".xml", signedXml) → byte[] ZIP in memory
  ├─ BuildSendBillEnvelope(zipKey, base64Zip)
  ├─ PostSoapAsync → SendBillAsync       → DIAN returns XmlDocumentKey (TrackId)
  ├─ DianRepo.ActualizarTrackId         → SP_DIAN_GUARDAR_TRACK
  └─ PollAsync(idFactura, trackId, endpoint)
       ├─ (up to 5 times, 3s delay each)
       ├─ BuildGetStatusEnvelope(trackId)
       ├─ PostSoapAsync → GetStatus      → IsValid, StatusCode, StatusDescription, QRStr
       ├─ If StatusCode in {00, 01, 66} → still processing, keep polling
       └─ DianRepo.ActualizarEstado      → SP_DIAN_ACTUALIZAR_ESTADO
            │
            ▼
      Returns DianEnvioResultDto { EstadoDian, QrDian, TrackId, DianStatusCode, ... }
```

### Status Mapping

| DIAN Response | `ESTADO_DIAN` |
|---------------|---------------|
| `IsValid = true` | `VALIDADA` |
| `StatusCode` in `{00, 01, 66}` after all polls | `PENDIENTE` |
| Any other code, `IsValid = false` | `RECHAZADA` |
| `HttpRequestException` or `TaskCanceledException` | `CONTINGENCIA` |

### SQL Script

Run **`sp_dian_fase3.sql`** before first use. It:
1. Adds `TRACK_ID_DIAN VARCHAR(100) NULL` to `FACTURAS`
2. Creates `SP_DIAN_OBTENER_XML` — fetches signed XML + metadata for a pending invoice
3. Creates `SP_DIAN_GUARDAR_TRACK` — saves the DIAN TrackId returned by `SendBillAsync`

### C# Files

| File | Layer | Purpose |
|------|-------|---------|
| `CORE.MMms/DTOs/DianDTOs.cs` | CORE | `DianXmlPendienteDto`, `DianEnvioResultDto` (added) |
| `CORE.MMms/Interfaces/IDian.cs` | CORE | `GetXmlPendiente`, `ActualizarTrackId` (added) |
| `CORE.MMms/Interfaces/IDianTransmissionService.cs` | CORE | Service contract: `EnviarFacturaAsync`, `ConsultarEstadoAsync` |
| `INFRA.MMms/Repository/DianRepo.cs` | INFRA | Implements `GetXmlPendiente` + `ActualizarTrackId` |
| `INFRA.MMms/Services/DianTransmissionService.cs` | INFRA | SOAP client, ZIP builder, polling, status mapping |
| `API.MMms/Controllers/DianController.cs` | API | `POST api/Dian/EnviarFactura/{id}`, `POST api/Dian/ConsultarEstado/{id}` |
| `API.MMms/Resolvers/MotoMasters_Dependencies.cs` | API | `AddHttpClient("dian")` + `IDianTransmissionService` registration |

### Configuration

Add real values to `API.MMms/appsettings.json` before testing:

```json
"Dian": {
  "CertificadoRuta": "C:/cert/empresa.p12",
  "CertificadoClave": "change-me",
  "SoftwareId": "your-software-id",
  "SoftwarePin": "your-software-pin"
}
```

> **Security:** `SoftwarePin` is sensitive. Use environment variables or a secrets manager
> in production. Never commit real credentials to source control.

### DI Registration Order (full DIAN stack)

```csharp
services.AddTransient<IDian,                    DianRepo>();
services.AddTransient<IXadesSignerService,      XadesSignerService>();   // Phase 2
services.AddTransient<IDianXmlService,          DianXmlService>();        // depends on IDian + IXadesSignerService
services.AddHttpClient("dian", c => c.Timeout = TimeSpan.FromSeconds(30)); // Phase 3
services.AddTransient<IDianTransmissionService, DianTransmissionService>(); // depends on IDian + IHttpClientFactory
```

### Retry / Contingency

- Network errors and timeouts → `ESTADO_DIAN = 'CONTINGENCIA'`; invoice retains its `TRACK_ID_DIAN` if one was already assigned.
- Use `POST api/Dian/ConsultarEstado/{idFactura}` to re-poll DIAN for invoices stuck in `PENDIENTE` or `CONTINGENCIA` (requires a `TRACK_ID_DIAN` already saved).
- Polling: up to 5 attempts × 3 s delay = max 15 s wait per call. If DIAN is still processing after 5 polls, status is set to `PENDIENTE` and the client must call `ConsultarEstado` again later.

---

## Phase 4 — Frontend ✅

**Scope:** Surface DIAN status information to the user and provide a full configuration UI.

### SQL Script

Run **`sp_dian_config.sql`** (Phase 4 additions) and **`sp_dian_reporte.sql`** before first use.

`sp_dian_config.sql` creates:

| SP | Purpose |
|----|---------|
| `SP_DIAN_EMPRESA_CONSULTAR` | Read company DIAN fields from `CONFIGURACIONES` |
| `SP_DIAN_EMPRESA_ACTUALIZAR` | Update company DIAN fields |
| `SP_DIAN_RESOLUCIONES_LISTAR` | List all resolutions with `DIAS_VIGENCIA` + `NUMEROS_DISPONIBLES` |
| `SP_DIAN_RESOLUCION_CREAR` | Insert new resolution; `NUMERO_ACTUAL = RANGO_INICIO − 1` |
| `SP_DIAN_RESOLUCION_ACTIVAR` | Deactivate same-type resolutions, activate target |
| `SP_DIAN_TIPOS_IVA` | Catalog: `ID_TIPO_IVA`, `TIPO_IVA` label, `PORCENTAJE`, `CODIGO_DIAN` |
| `SP_DIAN_PRODUCTO_CAMPOS` | Read `CODIGO_UNSPSC` + `IDX_TIPO_IVA` for a product |
| `SP_DIAN_ACTUALIZAR_PRODUCTO` | Update DIAN fields on a product row |
| `SP_DIAN_CLIENTE_CAMPOS` | Read `MUNICIPIO_DIAN`, `CODIGO_POSTAL`, `DIGITO_VERIFICACION` for a client |
| `SP_DIAN_ACTUALIZAR_CLIENTE` | Update DIAN fields on a client row |
| `SP_DIAN_PAGO_CAMPOS` | Read `CODIGO_MEDIO_PAGO_DIAN` for a payment method |
| `SP_DIAN_ACTUALIZAR_PAGO` | Update DIAN payment code on a payment method row |

`sp_dian_reporte.sql` creates:

| SP | Purpose |
|----|---------|
| `SP_DIAN_REPORTE_ESTADOS` | Invoice list filtered by `@estado_dian`, `@fecha_inicio`, `@fecha_fin`; ordered RECHAZADA → CONTINGENCIA → PENDIENTE → VALIDADA |

### Part A — Invoice Status UI

#### Invoice List (`finanzas.component`)

- Each invoice card in the list now shows a DIAN status badge alongside the payment badge when `ESTADO_DIAN` is set.
- Badge classes: `dian-card-pendiente` (gray), `dian-card-validada` (green), `dian-card-rechazada` (red), `dian-card-contingencia` (orange).

#### Invoice Detail Dialog (`factura.component`)

A DIAN section is rendered between the invoice header and the product list:

| Element | Condition | Description |
|---------|-----------|-------------|
| Status badge | Always | Color-coded icon + label |
| Rejection callout | `RECHAZADA` | Red box showing `NOTAS_DIAN` |
| QR link | `VALIDADA` | Link to `QR_DIAN` URL |
| **Generar XML** button | No `CUFE` yet | Calls `POST api/Dian/GenerarXml/{id}` |
| **Enviar a DIAN** button | Has `CUFE` + not `VALIDADA` | Calls `POST api/Dian/EnviarFactura/{id}` |
| **Consultar** button | `PENDIENTE` or `CONTINGENCIA` | Calls `POST api/Dian/ConsultarEstado/{id}` |
| **Procesando…** spinner | During any DIAN call | Replaces action buttons while in-flight |

All three action calls reload the invoice data on success to reflect the new status.

### Part B — DIAN Report Page

**Route:** `MotoMasters/DIAN` — accessible from Reportes → DIAN in the sidenav.

**Component:** `src/app/paginas/reportes-dian/reportes-dian.component`

Features:
- Summary cards: total Validadas / Pendientes / Rechazadas / Contingencias
- Filter bar: status selector + date range → `GET api/Dian/Reporte?estadoDian=&fechaInicio=&fechaFin=`
- Results table: invoice number, DIAN number, CUFE, client, date, total, status badge, notes/QR
- Per-row checkbox selection
- **Seleccionar no enviadas** — auto-selects rows that have a CUFE but are not yet `VALIDADA` (`PENDIENTE` or `CONTINGENCIA`)
- **Enviar lote** — calls `POST api/Dian/EnviarLote` with `{ ids: number[] }`; all invoices transmitted in parallel via `Task.WhenAll`

Backend additions for the report:
- `IDian.GetReporte(estadoDian, fechaInicio, fechaFin)` → `SP_DIAN_REPORTE_ESTADOS`
- `GET api/Dian/Reporte` — optional query params `estadoDian`, `fechaInicio`, `fechaFin`
- `IDianTransmissionService.EnviarLoteAsync(long[] ids)` → parallel `Task.WhenAll` over `EnviarFacturaAsync`
- `POST api/Dian/EnviarLote` — body `{ ids: number[] }` — returns `DianLoteResultDto { Total, Validadas, Rechazadas, Pendientes, Contingencias, Detalle }`

### Part B — DIAN Configuration Page

**Route:** `MotoMasters/DIAN-Config` — accessible from Configurar → Config DIAN in the sidenav.

**Component:** `src/app/paginas/dian-config/dian-config.component`

Two tabs:

#### Tab 1 — Empresa

Reads from `GET api/DianConfig/Empresa` and writes via `PUT api/DianConfig/Empresa`.

| Field | Source |
|-------|--------|
| Nombre comercial | `CONFIGURACIONES.NOMBRE_COMERCIAL` |
| Dígito de verificación (NIT) | `CONFIGURACIONES.DIGITO_VERIFICACION` |
| Municipio DANE | `CONFIGURACIONES.MUNICIPIO_DIAN` |
| Departamento DANE | `CONFIGURACIONES.DEPARTAMENTO_DIAN` |
| Código postal | `CONFIGURACIONES.CODIGO_POSTAL` |
| Ambiente DIAN | `CONFIGURACIONES.AMBIENTE_DIAN` (1 = Producción, 2 = Habilitación) |
| Tipo de documento empresa | FK → `TIPO_DOCUMENTO` |
| Régimen tributario | FK → `REGIMENES_TRIBUTARIOS` |
| Responsabilidad fiscal | FK → `RESPONSABILIDADES_FISCALES` |

Dropdowns are populated from `GET api/Clients/ConsultaFiscalTodo` (same endpoint used by client forms).

#### Tab 2 — Resoluciones

Lists all resolutions from `GET api/DianConfig/Resoluciones`. Each card shows:
- Resolution number (with prefix if any) and type badge (`FC` / `NC` / `ND`)
- Status badges: `ACTIVA` (teal), `VENCIDA` (red), or remaining days warning when ≤ 30 days
- Date range
- Progress bar: `NUMERO_ACTUAL` vs `RANGO_FIN` with available numbers remaining
- **Activar** button (hidden when already active) → `PUT api/DianConfig/Resoluciones/{id}/Activar?tipo=FC`

**Nueva resolución** form (toggle):
- Required: N° resolución, fecha inicio, fecha fin, rango inicio, rango fin, clave técnica
- Optional: prefijo, fecha resolución, tipo
- `POST api/DianConfig/Resoluciones` → `SP_DIAN_RESOLUCION_CREAR`; `NUMERO_ACTUAL` is initialized to `RANGO_INICIO − 1`

### Part B — DIAN Fields in Existing Forms

All DIAN field sections are **edit-only** (hidden when creating a new record) and save independently via their own "Guardar DIAN" button, leaving the main form and its SP untouched.

#### Productos / Agregar-Editar

| Field | Endpoint |
|-------|----------|
| Código UNSPSC (text) | `GET / PUT api/DianConfig/Producto/{id}` |
| Tipo IVA DIAN (select from `SP_DIAN_TIPOS_IVA`) | same |

#### Clientes / Agregar-Editar

| Field | Endpoint |
|-------|----------|
| Municipio DANE | `GET / PUT api/DianConfig/Cliente/{id}` |
| Código postal | same |
| Dígito de verificación | same |

#### Formas de Pago / Agregar-Editar (standalone component)

| Field | Endpoint |
|-------|----------|
| Código medio de pago DIAN (select) | `GET / PUT api/DianConfig/FormaPago/{id}` |

Predefined DIAN payment codes offered in the select:

| Code | Meaning |
|------|---------|
| 10 | Efectivo |
| 20 | Cheque |
| 22 | Débito |
| 48 | Transferencia crédito |
| 49 | Instrumento no definido |
| 71 | Efectivo electrónico |

`MatSelectModule`, `NgIf`, and `NgFor` were added to the standalone component's `imports` array to support this field.

### C# Files (Phase 4)

| File | Layer | Purpose |
|------|-------|---------|
| `CORE.MMms/DTOs/DianConfigDTOs.cs` | CORE | `DianEmpresaDto`, `DianResolucionDto`, `DianProductoCamposDto`, `DianClienteCamposDto`, `DianPagoCampoDto` |
| `CORE.MMms/DTOs/DianDTOs.cs` | CORE | Added `DianLoteResultDto` for bulk send response |
| `CORE.MMms/Interfaces/IDianConfig.cs` | CORE | Config repo contract (all GET + update methods) |
| `CORE.MMms/Interfaces/IDian.cs` | CORE | Added `GetReporte(estadoDian, fechaInicio, fechaFin)` |
| `CORE.MMms/Interfaces/IDianTransmissionService.cs` | CORE | Added `EnviarLoteAsync(long[] ids)` |
| `INFRA.MMms/Repository/DianConfigRepo.cs` | INFRA | Implements `IDianConfig` via `Fill` / `Execute` helpers |
| `INFRA.MMms/Services/DianTransmissionService.cs` | INFRA | Added `EnviarLoteAsync` using `Task.WhenAll` |
| `API.MMms/Controllers/DianController.cs` | API | Added `GET api/Dian/Reporte`, `POST api/Dian/EnviarLote` |
| `API.MMms/Controllers/DianConfigController.cs` | API | All `api/DianConfig/...` endpoints |
| `API.MMms/Resolvers/MotoMasters_Dependencies.cs` | API | Added `IDianConfig` DI registration |

### Angular Files (Phase 4)

| File | Purpose |
|------|---------|
| `paginas/reportes-dian/reportes-dian.component.*` | DIAN report page (3 files: ts, html, css) |
| `paginas/dian-config/dian-config.component.*` | DIAN config page (3 files: ts, html, css) |
| `paginas/finanzas/finanzas.component.html/css` | Added DIAN badge to invoice cards |
| `paginas/finanzas/factura/factura.component.*` | Added DIAN section to detail dialog |
| `paginas/productos/agregar-editar/agregar-editar.component.*` | Added DIAN section (edit mode) |
| `paginas/clientes/agregar-editar/agregar-editar.component.*` | Added DIAN section (edit mode) |
| `paginas/formas-pago/agregar-editar/agregar-editar.component.*` | Added DIAN payment code field (standalone) |
| `app-routing.module.ts` | Routes: `DIAN`, `DIAN-Config` |
| `app.module.ts` | Declared: `ReportesDianComponent`, `DianConfigComponent` |
| `componentes/sidenav/sidenav.component.ts` | Menu: Reportes → DIAN; Configurar → Config DIAN |

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
| Original invoice date | Mandatory in XML (v1.9) | Mandatory in XML (v1.9) |

### Tasks

- [ ] Add `NOTAS_CREDITO` and `NOTAS_DEBITO` tables (or extend `FACTURAS` with `TIPO_DOCUMENTO` + `IDX_FACTURA_ORIGINAL`)
- [ ] Add `NC` and `ND` resolutions to `RESOLUCIONES_DIAN`
- [ ] Extend `SP_DIAN_DATOS_FACTURA` to support NC/ND
- [ ] Implement XML builders for `CreditNote` and `DebitNote`
- [ ] Connect credit note generation to the `anularFactura` flow
- [ ] Frontend: "Generar Nota Crédito" button on validated invoices

---

## File Map

```
Back_Ventas_Masters/
├── sp_anulacion.sql               — Invoice cancellation (prerequisite for fase 0)
├── sp_dian_fase0.sql              — Phase 0: schema, seed data, SPs
├── sp_dian_fase1_fixes.sql        — Phase 1 fixes: CLIENTES.DIGITO_VERIFICACION,
│                                    FACTURAS.FECHA_VENCIMIENTO, SP_DIAN_DATOS_FACTURA update
├── sp_balance_diario.sql          — SP_BALANCE_DIARIO_IMPRIMIBLE (excludes ANULADO)
├── nuevos_sps.sql                 — Analytics SPs (excludes ANULADO)
├── sp_dian_fase3.sql              — Phase 3: TRACK_ID_DIAN + SP_DIAN_OBTENER_XML + SP_DIAN_GUARDAR_TRACK
├── sp_dian_reporte.sql            — Phase 4: SP_DIAN_REPORTE_ESTADOS
├── sp_dian_config.sql             — Phase 4: 12 config SPs (empresa, resoluciones, productos,
│                                    clientes, formas de pago, tipos IVA)
├── CREAR_ESTRUCTURA.sql           — Original DB creation script (read-only reference)
├── README_DIAN.md                 — This file
│
├── CORE.MMms/DTOs/
│   ├── DianDTOs.cs                — DianGenerarXmlResultDto, DianActualizarEstadoDto,
│   │                                DianXmlPendienteDto, DianEnvioResultDto [P3]
│   │                                DianLoteResultDto [P4]
│   └── DianConfigDTOs.cs          — DianEmpresaDto, DianResolucionDto, DianProductoCamposDto,
│                                    DianClienteCamposDto, DianPagoCampoDto [P4]
│
├── CORE.MMms/Interfaces/
│   ├── IDian.cs                   — GetDatosFactura, ActualizarEstado [P1]
│   │                                GetXmlPendiente, ActualizarTrackId [P3]
│   │                                GetReporte [P4]
│   ├── IDianXmlService.cs         — GenerarXml [P1]
│   ├── IXadesSignerService.cs     — FirmarXml, ValidarFirma [P2]
│   ├── IDianTransmissionService.cs — EnviarFacturaAsync, ConsultarEstadoAsync [P3]
│   │                                EnviarLoteAsync [P4]
│   └── IDianConfig.cs             — All config repo methods [P4]
│
├── INFRA.MMms/Repository/
│   ├── DianRepo.cs                — ADO.NET: all DIAN invoice SPs
│   └── DianConfigRepo.cs          — ADO.NET: all DIAN config SPs [P4]
│
├── INFRA.MMms/Services/
│   ├── DianXmlService.cs          — UBL 2.1 builder + CUFE + calls XadesSignerService
│   ├── XadesSignerService.cs      — XAdES-B-BES signing and local validation [P2]
│   └── DianTransmissionService.cs — SOAP client, ZIP, WS-Security, polling [P3]
│                                    EnviarLoteAsync (Task.WhenAll) [P4]
│
├── API.MMms/Controllers/
│   ├── DianController.cs          — POST   api/Dian/GenerarXml/{id}
│   │                                POST   api/Dian/EnviarFactura/{id} [P3]
│   │                                POST   api/Dian/ConsultarEstado/{id} [P3]
│   │                                GET    api/Dian/Reporte [P4]
│   │                                POST   api/Dian/EnviarLote [P4]
│   └── DianConfigController.cs    — GET/PUT api/DianConfig/Empresa [P4]
│                                    GET/POST api/DianConfig/Resoluciones [P4]
│                                    PUT    api/DianConfig/Resoluciones/{id}/Activar [P4]
│                                    GET    api/DianConfig/TiposIva [P4]
│                                    GET/PUT api/DianConfig/Producto/{id} [P4]
│                                    GET/PUT api/DianConfig/Cliente/{id} [P4]
│                                    GET/PUT api/DianConfig/FormaPago/{id} [P4]
│
└── API.MMms/Resolvers/
    └── MotoMasters_Dependencies.cs — DI: full DIAN stack + AddHttpClient("dian") + IDianConfig [P4]
```

---

## Execution Order (SQL Scripts)

```sql
-- 1. Verify ANULADO column exists
SELECT TOP 1 ANULADO FROM FACTURAS;
-- If error: ALTER TABLE FACTURAS ADD ANULADO BIT NULL DEFAULT 0;

-- 2. Run cancellation SP
-- sp_anulacion.sql

-- 3. Run Phase 0
-- sp_dian_fase0.sql

-- 4. Run Phase 1 fixes
-- sp_dian_fase1_fixes.sql

-- 4b. Run Phase 3 (adds TRACK_ID_DIAN + 2 new SPs)
-- sp_dian_fase3.sql

-- 4c. Run Phase 4 config SPs (empresa, resoluciones, producto, cliente, formas pago)
-- sp_dian_config.sql

-- 4d. Run Phase 4 report SP
-- sp_dian_reporte.sql

-- 5. Populate company DIAN data (run once, adapt values)
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

-- 6. Register active FC resolution
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

-- 7. Set UNSPSC defaults on existing products
UPDATE PRODUCTOS SET CODIGO_UNSPSC = '25172000', IDX_TIPO_IVA = 1
WHERE IDX_TIPO_IVA IS NULL;   -- 1 = IVA 19% from TIPOS_IVA

-- 8. Set DIAN payment codes on FORMAS_PAGO
UPDATE FORMAS_PAGO SET CODIGO_MEDIO_PAGO_DIAN = '10' WHERE MANEJA_CREDITO = 0; -- efectivo
UPDATE FORMAS_PAGO SET CODIGO_MEDIO_PAGO_DIAN = '30' WHERE MANEJA_CREDITO = 1; -- crédito

-- 9. Set buyer DV for business clients (run per client with NIT)
-- UPDATE CLIENTES SET DIGITO_VERIFICACION = '<dv>' WHERE CLIENTE_ID = <id>;
-- Leave NULL for natural persons (CC / CE) — defaults to '0' in the XML.
```

---

## Complete Flow: Invoice → Signed XML

```
POST /api/Dian/GenerarXml/{idFactura}
        │
        ▼
DianController.GenerarXml
        │
        ▼
DianXmlService.GenerarXml
  ├─ DianRepo.GetDatosFactura          → SP_DIAN_DATOS_FACTURA (4 result sets)
  ├─ CalcularCufe                      → SHA-384 over concatenated fields
  ├─ BuildUblXml                       → XDocument (UBL 2.1, empty ExtensionContent)
  ├─ XadesSignerService.FirmarXml
  │    ├─ Load .p12 certificate
  │    ├─ Embed placeholder ds:Signature in ExtensionContent
  │    ├─ Compute SHA-256 digests (doc, KeyInfo, SignedProperties) in document context
  │    ├─ Patch DigestValues in DOM
  │    ├─ Exc-C14N(ds:SignedInfo) → RSA-SHA256 sign
  │    └─ Write ds:SignatureValue
  ├─ XadesSignerService.ValidarFirma   → local SignedXml.CheckSignature()
  └─ DianRepo.ActualizarEstado         → SP_DIAN_ACTUALIZAR_ESTADO
                                          (saves CUFE + signed XML, state = PENDIENTE)
        │
        ▼
Returns DianGenerarXmlResultDto { IdFactura, Cufe, Xml, EstadoDian="PENDIENTE", NumeroFacturaDian }
```

---

## Known Limitations / Notes

- **`SP_BALANCE_DIARIO_IMPRIMIBLE`** does not filter `ANULADO` invoices from Result 1 (facturas). This is intentional — the balance report shows all transactions including cancelled ones for audit purposes.
- **`SP_DIAN_DATOS_FACTURA` Phase 0 version** is missing `adquirente_digito_verificacion`, `fecha_vencimiento_dian`, `prepago`, and `maneja_credito`. The C# service requires the **Phase 1 fixes** version. Do not skip `sp_dian_fase1_fixes.sql`.
- **Service UNSPSC default** for service lines is hardcoded as `80111500` (Management support services) in the SP. Update per-service if needed.
- **Product UNSPSC default** is `25172000` (motorcycle parts) — update `PRODUCTOS.CODIGO_UNSPSC` for products in other categories.
- **`CUFE_FACTURA`** was part of the original schema (`CREAR_ESTRUCTURA.sql`) — Phase 0 does not add it via `ALTER TABLE`.
