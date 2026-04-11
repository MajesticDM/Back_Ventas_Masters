USE [MOTO_MASTERS]
GO

-- ============================================================
-- DIAN FASE 0 — Esquema de Base de Datos
-- Fecha: 2026-04-11
-- Seguro re-ejecutar: ALTER TABLE usa IF NOT EXISTS;
--                     tablas nuevas usan IF NOT EXISTS;
--                     SPs usan CREATE OR ALTER.
--
-- Orden de ejecución requerido: primero sp_anulacion.sql
--
-- Contenido:
--  A. Nuevas tablas
--     1. RESOLUCIONES_DIAN   — resoluciones habilitadas por DIAN
--     2. TIPOS_IVA           — catálogo de tipos de IVA
--  B. ALTER TABLE (solo agrega columnas, no toca las existentes)
--     3. FACTURAS            — NUMERO_FACTURA_DIAN, ESTADO_DIAN,
--                              FECHA_VALIDACION_DIAN, QR_DIAN,
--                              XML_DIAN, NOTAS_DIAN
--     4. CONFIGURACIONES     — campos DIAN del emisor
--     5. PRODUCTOS           — CODIGO_UNSPSC, IDX_TIPO_IVA
--     6. CLIENTES            — MUNICIPIO_DIAN, CODIGO_POSTAL
--     7. FORMAS_PAGO         — CODIGO_MEDIO_PAGO_DIAN
--  C. Datos iniciales
--     8. TIPOS_IVA seed
--  D. Stored Procedures
--     9.  SP_DIAN_SIGUIENTE_NUMERO  (nuevo) — número atómico de resolución
--     10. SP_DIAN_ACTUALIZAR_ESTADO (nuevo) — guarda CUFE/QR/estado post-envío
--     11. SP_DIAN_DATOS_FACTURA     (nuevo) — payload completo para XML UBL 2.1
--     12. SP_FACTURAS_ACCIONES      (reescritura completa, incluye anularFactura
--                                    + asignación de NUMERO_FACTURA_DIAN)
--     13. SP_CARGADO_FACTURAS       (reescritura completa, incluye ANULADO
--                                    + campos DIAN en table0)
-- ============================================================


-- ============================================================
-- A.1  RESOLUCIONES_DIAN
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'RESOLUCIONES_DIAN')
BEGIN
    CREATE TABLE [dbo].[RESOLUCIONES_DIAN] (
        [ID_RESOLUCION]         NUMERIC(18,0) IDENTITY(1,1) NOT NULL,
        [NUMERO_RESOLUCION]     VARCHAR(20)   NOT NULL,   -- ej. '18764030000001'
        [FECHA_RESOLUCION]      DATE          NOT NULL,
        [FECHA_INICIO_VIGENCIA] DATE          NOT NULL,
        [FECHA_FIN_VIGENCIA]    DATE          NOT NULL,
        [PREFIJO]               VARCHAR(10)   NULL,       -- ej. 'SETT' o vacío
        [RANGO_INICIO]          NUMERIC(18,0) NOT NULL,
        [RANGO_FIN]             NUMERIC(18,0) NOT NULL,
        [NUMERO_ACTUAL]         NUMERIC(18,0) NOT NULL DEFAULT 0, -- consecutivo actual
        [CLAVE_TECNICA]         VARCHAR(200)  NOT NULL,
        [TIPO]                  VARCHAR(2)    NOT NULL DEFAULT 'FC', -- FC | NC | ND
        [ACTIVA]                BIT           NOT NULL DEFAULT 1,
        CONSTRAINT [PK_RESOLUCIONES_DIAN] PRIMARY KEY CLUSTERED ([ID_RESOLUCION] ASC)
    );
    PRINT 'Tabla RESOLUCIONES_DIAN creada.';
END
ELSE
    PRINT 'Tabla RESOLUCIONES_DIAN ya existe — omitida.';
GO


-- ============================================================
-- A.2  TIPOS_IVA
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'TIPOS_IVA')
BEGIN
    CREATE TABLE [dbo].[TIPOS_IVA] (
        [ID_TIPO_IVA]      NUMERIC(18,0) IDENTITY(1,1) NOT NULL,
        [DESCRIPCION]      VARCHAR(100)  NOT NULL,
        [PORCENTAJE]       NUMERIC(5,2)  NOT NULL,
        [CODIGO_TRIBUTO]   VARCHAR(10)   NOT NULL,   -- '01'=IVA, 'ZZ'=No causa
        [NOMBRE_TRIBUTO]   VARCHAR(50)   NOT NULL,   -- 'IVA', 'No causa', etc.
        [ACTIVO]           BIT           NOT NULL DEFAULT 1,
        CONSTRAINT [PK_TIPOS_IVA] PRIMARY KEY CLUSTERED ([ID_TIPO_IVA] ASC)
    );
    PRINT 'Tabla TIPOS_IVA creada.';
END
ELSE
    PRINT 'Tabla TIPOS_IVA ya existe — omitida.';
GO


-- ============================================================
-- B.3  ALTER TABLE FACTURAS — campos DIAN
-- ============================================================
IF COL_LENGTH('FACTURAS', 'NUMERO_FACTURA_DIAN') IS NULL
    ALTER TABLE FACTURAS ADD [NUMERO_FACTURA_DIAN] NUMERIC(18,0) NULL;
GO
IF COL_LENGTH('FACTURAS', 'ESTADO_DIAN') IS NULL
    -- PENDIENTE | VALIDADA | RECHAZADA | CONTINGENCIA | NULL (no enviada aún)
    ALTER TABLE FACTURAS ADD [ESTADO_DIAN] VARCHAR(20) NULL;
GO
IF COL_LENGTH('FACTURAS', 'FECHA_VALIDACION_DIAN') IS NULL
    ALTER TABLE FACTURAS ADD [FECHA_VALIDACION_DIAN] DATETIME NULL;
GO
IF COL_LENGTH('FACTURAS', 'QR_DIAN') IS NULL
    ALTER TABLE FACTURAS ADD [QR_DIAN] VARCHAR(500) NULL;
GO
IF COL_LENGTH('FACTURAS', 'XML_DIAN') IS NULL
    ALTER TABLE FACTURAS ADD [XML_DIAN] VARCHAR(MAX) NULL;
GO
IF COL_LENGTH('FACTURAS', 'NOTAS_DIAN') IS NULL
    ALTER TABLE FACTURAS ADD [NOTAS_DIAN] VARCHAR(1000) NULL;
GO


-- ============================================================
-- B.4  ALTER TABLE CONFIGURACIONES — datos DIAN del emisor
-- ============================================================
IF COL_LENGTH('CONFIGURACIONES', 'NOMBRE_COMERCIAL') IS NULL
    ALTER TABLE CONFIGURACIONES ADD [NOMBRE_COMERCIAL] VARCHAR(200) NULL;
GO
IF COL_LENGTH('CONFIGURACIONES', 'DIGITO_VERIFICACION') IS NULL
    -- Dígito de verificación del NIT (1 carácter numérico)
    ALTER TABLE CONFIGURACIONES ADD [DIGITO_VERIFICACION] VARCHAR(2) NULL;
GO
IF COL_LENGTH('CONFIGURACIONES', 'MUNICIPIO_DIAN') IS NULL
    -- Código DANE del municipio — ej. '11001' para Bogotá
    ALTER TABLE CONFIGURACIONES ADD [MUNICIPIO_DIAN] VARCHAR(10) NULL;
GO
IF COL_LENGTH('CONFIGURACIONES', 'DEPARTAMENTO_DIAN') IS NULL
    -- Código DANE del departamento — ej. '11' para Bogotá DC
    ALTER TABLE CONFIGURACIONES ADD [DEPARTAMENTO_DIAN] VARCHAR(10) NULL;
GO
IF COL_LENGTH('CONFIGURACIONES', 'CODIGO_POSTAL') IS NULL
    ALTER TABLE CONFIGURACIONES ADD [CODIGO_POSTAL] VARCHAR(10) NULL;
GO
IF COL_LENGTH('CONFIGURACIONES', 'IDX_TIPO_DOCUMENTO_EMPRESA') IS NULL
    -- Usualmente NIT → ID en TIPO_DOCUMENTO con EQUIVALENCIA_TIPO = '31'
    ALTER TABLE CONFIGURACIONES ADD [IDX_TIPO_DOCUMENTO_EMPRESA] NUMERIC(18,0) NULL;
GO
IF COL_LENGTH('CONFIGURACIONES', 'IDX_REGIMEN_TRIBUTARIO_EMPRESA') IS NULL
    ALTER TABLE CONFIGURACIONES ADD [IDX_REGIMEN_TRIBUTARIO_EMPRESA] NUMERIC(18,0) NULL;
GO
IF COL_LENGTH('CONFIGURACIONES', 'IDX_RESPONSABILIDAD_FISCAL_EMPRESA') IS NULL
    ALTER TABLE CONFIGURACIONES ADD [IDX_RESPONSABILIDAD_FISCAL_EMPRESA] NUMERIC(18,0) NULL;
GO
IF COL_LENGTH('CONFIGURACIONES', 'SOFTWARE_ID_DIAN') IS NULL
    -- Identificador del software registrado en el portal DIAN
    ALTER TABLE CONFIGURACIONES ADD [SOFTWARE_ID_DIAN] VARCHAR(100) NULL;
GO
IF COL_LENGTH('CONFIGURACIONES', 'SOFTWARE_PIN_DIAN') IS NULL
    ALTER TABLE CONFIGURACIONES ADD [SOFTWARE_PIN_DIAN] VARCHAR(50) NULL;
GO
IF COL_LENGTH('CONFIGURACIONES', 'AMBIENTE_DIAN') IS NULL
    -- 1 = Producción, 2 = Habilitación/Pruebas
    ALTER TABLE CONFIGURACIONES ADD [AMBIENTE_DIAN] TINYINT NULL DEFAULT 2;
GO


-- ============================================================
-- B.5  ALTER TABLE PRODUCTOS — campos DIAN
-- ============================================================
IF COL_LENGTH('PRODUCTOS', 'CODIGO_UNSPSC') IS NULL
    -- Código UN Standard Products and Services Code — ej. '25172000'
    ALTER TABLE PRODUCTOS ADD [CODIGO_UNSPSC] VARCHAR(15) NULL;
GO
IF COL_LENGTH('PRODUCTOS', 'IDX_TIPO_IVA') IS NULL
    ALTER TABLE PRODUCTOS ADD [IDX_TIPO_IVA] NUMERIC(18,0) NULL;
GO


-- ============================================================
-- B.6  ALTER TABLE CLIENTES — datos de ubicación para XML
-- ============================================================
IF COL_LENGTH('CLIENTES', 'MUNICIPIO_DIAN') IS NULL
    ALTER TABLE CLIENTES ADD [MUNICIPIO_DIAN] VARCHAR(10) NULL;
GO
IF COL_LENGTH('CLIENTES', 'CODIGO_POSTAL') IS NULL
    ALTER TABLE CLIENTES ADD [CODIGO_POSTAL] VARCHAR(10) NULL;
GO


-- ============================================================
-- B.7  ALTER TABLE FORMAS_PAGO — código DIAN de medio de pago
-- Códigos más comunes:
--   10 = Efectivo       20 = Cheque
--   30 = Crédito        42 = Consignación/Transferencia
--   48 = Tarjeta crédito  49 = Tarjeta débito
--   ZZZ = Otro
-- ============================================================
IF COL_LENGTH('FORMAS_PAGO', 'CODIGO_MEDIO_PAGO_DIAN') IS NULL
    ALTER TABLE FORMAS_PAGO ADD [CODIGO_MEDIO_PAGO_DIAN] VARCHAR(5) NULL;
GO


-- ============================================================
-- C.8  Seed TIPOS_IVA
-- Solo inserta si la tabla está vacía (idempotente)
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM TIPOS_IVA)
BEGIN
    INSERT INTO TIPOS_IVA (DESCRIPCION, PORCENTAJE, CODIGO_TRIBUTO, NOMBRE_TRIBUTO) VALUES
    ('IVA 19%',  19.00, '01', 'IVA'),
    ('IVA 5%',    5.00, '01', 'IVA'),
    ('Exento',    0.00, '01', 'IVA'),      -- aplica IVA a tarifa 0%
    ('Excluido',  0.00, 'ZZ', 'No causa'); -- no sujeto a IVA
    PRINT 'TIPOS_IVA: 4 registros insertados.';
END
ELSE
    PRINT 'TIPOS_IVA ya tiene datos — seed omitido.';
GO


-- ============================================================
-- D.9  SP_DIAN_SIGUIENTE_NUMERO
--      Obtiene y reserva atómicamente el siguiente número
--      consecutivo de la resolución activa del tipo indicado.
--      Retorna: numero_dian (NULL si no hay resolución activa
--               o si el rango está agotado).
-- ============================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SP_DIAN_SIGUIENTE_NUMERO]
    @tipo VARCHAR(2) = 'FC'   -- FC | NC | ND
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @captura TABLE (
        numero_dian         NUMERIC(18,0),
        prefijo             VARCHAR(10),
        numero_resolucion   VARCHAR(20),
        fecha_resolucion    DATE,
        fecha_inicio        DATE,
        fecha_fin           DATE,
        rango_inicio        NUMERIC(18,0),
        rango_fin           NUMERIC(18,0),
        clave_tecnica       VARCHAR(200)
    );

    -- Incremento atómico con OUTPUT: si no hay resolución activa
    -- o el rango está agotado, no se actualiza ninguna fila.
    UPDATE RESOLUCIONES_DIAN
    SET NUMERO_ACTUAL = NUMERO_ACTUAL + 1
    OUTPUT
        INSERTED.NUMERO_ACTUAL,
        INSERTED.PREFIJO,
        INSERTED.NUMERO_RESOLUCION,
        INSERTED.FECHA_RESOLUCION,
        INSERTED.FECHA_INICIO_VIGENCIA,
        INSERTED.FECHA_FIN_VIGENCIA,
        INSERTED.RANGO_INICIO,
        INSERTED.RANGO_FIN,
        INSERTED.CLAVE_TECNICA
    INTO @captura
    WHERE ACTIVA = 1
      AND TIPO   = @tipo
      AND CAST(GETDATE() AS DATE) BETWEEN FECHA_INICIO_VIGENCIA AND FECHA_FIN_VIGENCIA
      AND NUMERO_ACTUAL < RANGO_FIN;

    SELECT
        numero_dian,
        prefijo,
        numero_resolucion,
        fecha_resolucion,
        fecha_inicio,
        fecha_fin,
        rango_inicio,
        rango_fin,
        clave_tecnica
    FROM @captura;
END
GO


-- ============================================================
-- D.10  SP_DIAN_ACTUALIZAR_ESTADO
--       Persiste el resultado del proceso DIAN en la factura.
--       Se llama desde el backend C# después de:
--         a) generar y firmar el XML (guarda XML_DIAN, CUFE)
--         b) recibir respuesta de DIAN   (guarda ESTADO_DIAN, QR, notas)
--       Solo actualiza los parámetros no-nulos para poder hacer
--       las dos llamadas por separado si es necesario.
-- ============================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SP_DIAN_ACTUALIZAR_ESTADO]
    @id_factura   NUMERIC(18,0),
    @cufe         VARCHAR(1000) = NULL,
    @estado_dian  VARCHAR(20)   = NULL,   -- PENDIENTE|VALIDADA|RECHAZADA|CONTINGENCIA
    @qr_dian      VARCHAR(500)  = NULL,
    @xml_dian     VARCHAR(MAX)  = NULL,
    @notas_dian   VARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE FACTURAS SET
        CUFE_FACTURA          = ISNULL(@cufe,        CUFE_FACTURA),
        ESTADO_DIAN           = ISNULL(@estado_dian,  ESTADO_DIAN),
        QR_DIAN               = ISNULL(@qr_dian,      QR_DIAN),
        XML_DIAN              = ISNULL(@xml_dian,      XML_DIAN),
        NOTAS_DIAN            = ISNULL(@notas_dian,   NOTAS_DIAN),
        FECHA_VALIDACION_DIAN = CASE
                                    WHEN @estado_dian = 'VALIDADA'
                                    THEN GETDATE()
                                    ELSE FECHA_VALIDACION_DIAN
                                END
    WHERE ID_FACTURA = @id_factura;

    SELECT CUFE_FACTURA, ESTADO_DIAN, QR_DIAN, FECHA_VALIDACION_DIAN
    FROM FACTURAS
    WHERE ID_FACTURA = @id_factura;
END
GO


-- ============================================================
-- D.11  SP_DIAN_DATOS_FACTURA
--       Devuelve el payload completo que el servicio C# necesita
--       para construir el XML UBL 2.1 y calcular el CUFE.
--
--       Resultado 0: Cabecera (1 fila)
--                    — datos de la factura + emisor + adquirente
--                      + resolución activa + forma de pago
--       Resultado 1: Líneas de productos
--       Resultado 2: Líneas de servicios
--       Resultado 3: Subtotales de impuestos (TaxTotal en UBL)
-- ============================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SP_DIAN_DATOS_FACTURA]
    @id_factura NUMERIC(18,0)
AS
BEGIN
    SET NOCOUNT ON;

    -- ----------------------------------------------------------
    -- Resultado 0: Cabecera + Emisor + Adquirente + Resolución
    -- ----------------------------------------------------------
    SELECT
        -- Factura
        F.ID_FACTURA,
        F.NUMERO_FACTURA_DIAN,
        F.CUFE_FACTURA,
        ISNULL(F.ESTADO_DIAN, 'PENDIENTE')          AS estado_dian,
        F.FECHA_VENTA,
        FORMAT(F.FECHA_VENTA, 'yyyyMMdd')            AS fecha_dian,         -- FecFac para CUFE
        FORMAT(F.FECHA_VENTA, 'HH:mm:ss')
            + '-05:00'                               AS hora_dian,          -- HorFac para CUFE
        F.COSTO_TOTAL                                AS total,
        ISNULL(F.VALOR_IVA, 0)                       AS total_iva,
        F.COSTO_TOTAL - ISNULL(F.VALOR_IVA, 0)      AS subtotal,
        F.CONSUMIDOR_FINAL,
        -- Emisor (empresa)
        CF.NOMBRE_LEGAL_ESTABLECIMIENTO              AS emisor_razon_social,
        ISNULL(CF.NOMBRE_COMERCIAL,
               CF.NOMBRE_LEGAL_ESTABLECIMIENTO)      AS emisor_nombre_comercial,
        CF.NIT_EMPRESA                               AS emisor_nit,
        ISNULL(CF.DIGITO_VERIFICACION, '0')          AS emisor_digito_verificacion,
        CF.DIRECCION                                 AS emisor_direccion,
        ISNULL(CF.MUNICIPIO_DIAN,    '11001')        AS emisor_municipio,
        ISNULL(CF.DEPARTAMENTO_DIAN, '11')           AS emisor_departamento,
        ISNULL(CF.CODIGO_POSTAL,     '110111')       AS emisor_codigo_postal,
        CF.TELEFONO                                  AS emisor_telefono,
        CF.EMAIL_EMPRESA                             AS emisor_email,
        ISNULL(CF.SOFTWARE_ID_DIAN,  '')             AS software_id,
        ISNULL(CF.SOFTWARE_PIN_DIAN, '')             AS software_pin,
        ISNULL(CF.AMBIENTE_DIAN, 2)                  AS ambiente_dian,
        ISNULL(RT_E.EQUIVALENCIA_REGIMEN_TRIBUTARIO, 'ZZ')  AS emisor_regimen,
        ISNULL(RF_E.EQUIVALENCIA_RESPONSABILIDAD,    'R-99-PN') AS emisor_responsabilidad,
        ISNULL(TD_E.EQUIVALENCIA_TIPO,               '31')  AS emisor_tipo_documento,
        -- Adquirente (cliente)
        CONCAT(CL.NOMBRES, ' ', CL.APELLIDOS)        AS adquirente_nombre,
        CL.IDENTIFICACION                            AS adquirente_identificacion,
        ISNULL(CL.CORREO_ELECTRONICO, '')            AS adquirente_email,
        CL.NUMERO_TELEFONO                           AS adquirente_telefono,
        ISNULL(CL.DIRECCION_FISCAL, 'No registrada') AS adquirente_direccion,
        ISNULL(CL.MUNICIPIO_DIAN,   '11001')         AS adquirente_municipio,
        ISNULL(CL.CODIGO_POSTAL,    '110111')        AS adquirente_codigo_postal,
        ISNULL(TD_C.EQUIVALENCIA_TIPO,    '13')      AS adquirente_tipo_documento,
        ISNULL(RT_C.EQUIVALENCIA_REGIMEN_TRIBUTARIO, 'ZZ')  AS adquirente_regimen,
        ISNULL(RF_C.EQUIVALENCIA_RESPONSABILIDAD,    'R-99-PN') AS adquirente_responsabilidad,
        -- Resolución activa FC (puede ser NULL si no está configurada)
        RD.NUMERO_RESOLUCION,
        ISNULL(RD.PREFIJO, '')                       AS prefijo_dian,
        RD.FECHA_RESOLUCION,
        RD.FECHA_INICIO_VIGENCIA,
        RD.FECHA_FIN_VIGENCIA,
        RD.RANGO_INICIO,
        RD.RANGO_FIN,
        RD.CLAVE_TECNICA,
        -- Forma de pago
        FP.FORMA_PAGO,
        ISNULL(FP.CODIGO_MEDIO_PAGO_DIAN, 'ZZZ')    AS codigo_medio_pago_dian,
        F.IDX_FORMA_PAGO,
        -- Indicador crédito/contado para UBL PaymentMeans
        CASE WHEN F.IDX_FORMA_PAGO = 2 THEN 'Crédito' ELSE 'Contado' END AS tipo_pago_dian
    FROM FACTURAS F
    INNER JOIN CLIENTES         CL    ON F.IDX_CLIENTE       = CL.CLIENTE_ID
    CROSS JOIN CONFIGURACIONES  CF                           -- fila única
    INNER JOIN FORMAS_PAGO      FP    ON F.IDX_FORMA_PAGO    = FP.ID_FORMA_PAGO
    -- Resolución activa FC (LEFT: no bloquea si aún no está configurada)
    LEFT JOIN RESOLUCIONES_DIAN RD
           ON RD.ACTIVA = 1
          AND RD.TIPO   = 'FC'
          AND CAST(F.FECHA_VENTA AS DATE) BETWEEN RD.FECHA_INICIO_VIGENCIA AND RD.FECHA_FIN_VIGENCIA
    -- Datos fiscales del emisor
    LEFT JOIN REGIMENES_TRIBUTARIOS   RT_E ON CF.IDX_REGIMEN_TRIBUTARIO_EMPRESA    = RT_E.ID_REGIMEN_TRIBUTARIO
    LEFT JOIN RESPONSABILIDADES_FISCALES RF_E ON CF.IDX_RESPONSABILIDAD_FISCAL_EMPRESA = RF_E.ID_RESPONSABILIDAD_FISCAL
    LEFT JOIN TIPO_DOCUMENTO          TD_E ON CF.IDX_TIPO_DOCUMENTO_EMPRESA        = TD_E.ID_TIPO_DOCUMENTO
    -- Datos fiscales del adquirente
    LEFT JOIN REGIMENES_TRIBUTARIOS   RT_C ON CL.IDX_REGIMEN_TRIBUTARIO            = RT_C.ID_REGIMEN_TRIBUTARIO
    LEFT JOIN RESPONSABILIDADES_FISCALES RF_C ON CL.IDX_RESPONSABILIDAD_FISCAL     = RF_C.ID_RESPONSABILIDAD_FISCAL
    LEFT JOIN TIPO_DOCUMENTO          TD_C ON CL.IDX_TIPO_DOCUMENTO                = TD_C.ID_TIPO_DOCUMENTO
    WHERE F.ID_FACTURA = @id_factura;

    -- ----------------------------------------------------------
    -- Resultado 1: Líneas de productos
    -- ----------------------------------------------------------
    SELECT
        ROW_NUMBER() OVER (ORDER BY VP.ID_VENDIDO_PRODUCT) AS numero_linea,
        P.PRODUCTO                                          AS descripcion,
        P.CODIGO_BARRAS                                     AS codigo_vendedor,
        ISNULL(P.CODIGO_UNSPSC, '25172000')                 AS codigo_unspsc,  -- partes moto por defecto
        VP.QUANTITY                                         AS cantidad,
        ISNULL(MP.EQUIVALENCIA_MEDIDA, 'EA')                AS unidad_medida,  -- EA = unidad
        VP.PRECIO_UNITARIO_VENTA                            AS precio_unitario,
        VP.SUB_TOTAL                                        AS subtotal_linea,
        ISNULL(TI.PORCENTAJE,     19.00)                    AS porcentaje_iva,
        ISNULL(TI.CODIGO_TRIBUTO, '01')                     AS codigo_tributo,
        ISNULL(TI.NOMBRE_TRIBUTO, 'IVA')                    AS nombre_tributo,
        VP.VALOR_IVA                                        AS valor_iva_linea,
        VP.TOTAL_COST                                       AS total_linea,
        VP.GRAMAJE_VENDIDO
    FROM VENDIDO_PRODUCTOS VP
    INNER JOIN PRODUCTOS     P    ON VP.IDX_PRODUCTO  = P.PRODUCT_ID
    LEFT  JOIN TIPOS_IVA     TI   ON P.IDX_TIPO_IVA   = TI.ID_TIPO_IVA
    LEFT  JOIN MEDIDAS_PESADO MP  ON P.IDX_MEDIDA      = MP.ID_MEDIDAS_PESADO
    WHERE VP.IDX_FACTURA = @id_factura;

    -- ----------------------------------------------------------
    -- Resultado 2: Líneas de servicios
    -- Los servicios no tienen código UNSPSC propio en el sistema;
    -- se usa '80111500' (Management support services) como default.
    -- ----------------------------------------------------------
    SELECT
        ROW_NUMBER() OVER (ORDER BY SD.SERVICIO_DADO_S_ID) AS numero_linea,
        S.SERVICIO                                          AS descripcion,
        '80111500'                                          AS codigo_unspsc,
        1                                                   AS cantidad,
        'ZZ'                                                AS unidad_medida,  -- no aplica
        SD.TOTAL_COST                                       AS precio_unitario,
        ISNULL(SD.SUB_TOTAL, SD.TOTAL_COST)                 AS subtotal_linea,
        0.00                                                AS porcentaje_iva,
        'ZZ'                                                AS codigo_tributo,
        'No causa'                                          AS nombre_tributo,
        ISNULL(SD.VALOR_IVA, 0)                             AS valor_iva_linea,
        SD.TOTAL_COST                                       AS total_linea
    FROM SERVICIOS_DADOS SD
    INNER JOIN SERVICIOS S ON SD.IDX_SERVICIO = S.SERVICIO_ID
    WHERE SD.IDX_FACTURA = @id_factura;

    -- ----------------------------------------------------------
    -- Resultado 3: Subtotales de impuestos (TaxTotal en UBL 2.1)
    -- Agrupa por tipo de IVA para generar cada TaxSubtotal.
    -- ----------------------------------------------------------
    SELECT
        ISNULL(TI.CODIGO_TRIBUTO,  '01')      AS codigo_tributo,
        ISNULL(TI.NOMBRE_TRIBUTO,  'IVA')     AS nombre_tributo,
        ISNULL(TI.PORCENTAJE,      19.00)      AS porcentaje,
        SUM(VP.SUB_TOTAL)                      AS base_gravable,
        SUM(VP.VALOR_IVA)                      AS valor_impuesto
    FROM VENDIDO_PRODUCTOS VP
    INNER JOIN PRODUCTOS P  ON VP.IDX_PRODUCTO = P.PRODUCT_ID
    LEFT  JOIN TIPOS_IVA TI ON P.IDX_TIPO_IVA  = TI.ID_TIPO_IVA
    WHERE VP.IDX_FACTURA = @id_factura
    GROUP BY TI.CODIGO_TRIBUTO, TI.NOMBRE_TRIBUTO, TI.PORCENTAJE;
END
GO


-- ============================================================
-- D.12  SP_FACTURAS_ACCIONES — reescritura completa
--       Incluye:
--         • crearFactura   — asigna NUMERO_FACTURA_DIAN de la
--                            resolución activa al crear la factura
--         • venderProducto — sin cambios respecto al original
--         • actualizarTotalIva — sin cambios
--         • anularFactura  — de sp_anulacion.sql (integrado aquí)
-- ============================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SP_FACTURAS_ACCIONES]
    @accion               VARCHAR(100),
    @id_factura           NUMERIC(18,0) = NULL,
    @idx_cliente          NUMERIC(18,0) = NULL,
    @idx_usuario          NUMERIC(18,0) = NULL,
    @costo_total          NUMERIC(18,2) = NULL,
    @estado               BIT           = NULL,
    @consumidor_final     BIT           = NULL,
    @cufe_factura         VARCHAR(1000) = NULL,
    @idx_producto         NUMERIC(18,0) = NULL,
    @cantidad             NUMERIC(18,2) = NULL,
    @forma_pago           NUMERIC(18,0) = NULL,
    @forma_pago_inicial   NUMERIC(18,0) = 0,
    @pago_inicial         NUMERIC(18,2) = NULL,
    @usa_saldo_favor      BIT           = NULL,
    @gramaje_total        NUMERIC(18,2) = NULL
AS
BEGIN
    DECLARE @porcentaje_iva NUMERIC(18,2) =
        ISNULL((SELECT TOP 1 PORCENTAJE_IVA FROM CONFIGURACIONES), 0);

    -- ----------------------------------------------------------
    IF (@accion = 'crearFactura')
    BEGIN
        DECLARE @saldo_favor    DECIMAL(18,2);
        DECLARE @saldo_negativo DECIMAL(18,2);
        DECLARE @caja           NUMERIC(18,0) =
            (SELECT TOP 1 ID_CAJA FROM CAJA
             WHERE IDX_USUARIO = @idx_usuario AND FECHA_CIERRE_CAJA IS NULL);

        SELECT @saldo_favor    = SALDO,
               @saldo_negativo = SALDO_NEGATIVO
        FROM CLIENTES WHERE CLIENTE_ID = @idx_cliente;

        IF (@usa_saldo_favor = 1)
        BEGIN
            DECLARE @disponible DECIMAL(18,2) = @saldo_favor;
            IF (@disponible >= @costo_total)
            BEGIN
                SET @pago_inicial   = @costo_total;
                SET @saldo_favor    = @disponible - @costo_total;
            END
            ELSE
            BEGIN
                SET @pago_inicial    = @disponible;
                SET @saldo_favor     = 0;
                SET @saldo_negativo  = @saldo_negativo + (@costo_total - @pago_inicial);
            END
        END
        ELSE
        BEGIN
            IF (@pago_inicial < @costo_total AND @forma_pago = 2)
                SET @saldo_negativo = @saldo_negativo + (@costo_total - @pago_inicial);
        END

        UPDATE CLIENTES SET
            SALDO          = @saldo_favor,
            SALDO_NEGATIVO = @saldo_negativo
        WHERE CLIENTE_ID = @idx_cliente;

        DECLARE @NuevoID INT;

        INSERT INTO FACTURAS (
            IDX_CLIENTE, IDX_USUARIO, COSTO_TOTAL, CONSUMIDOR_FINAL,
            IDX_FORMA_PAGO, VALOR_PAGADO, PAGO_INICIAL,
            IDX_CAJA, IDX_FORMA_PAGO_INICIAL
        )
        VALUES (
            @idx_cliente, @idx_usuario, @costo_total, @consumidor_final,
            @forma_pago, @pago_inicial, @pago_inicial,
            @caja, @forma_pago_inicial
        );

        SET @NuevoID = SCOPE_IDENTITY();

        -- Asignar número DIAN de la resolución activa (atómico)
        DECLARE @resolucion TABLE (
            numero_dian       NUMERIC(18,0),
            prefijo           VARCHAR(10),
            numero_resolucion VARCHAR(20),
            fecha_resolucion  DATE,
            fecha_inicio      DATE,
            fecha_fin         DATE,
            rango_inicio      NUMERIC(18,0),
            rango_fin         NUMERIC(18,0),
            clave_tecnica     VARCHAR(200)
        );

        UPDATE RESOLUCIONES_DIAN
        SET NUMERO_ACTUAL = NUMERO_ACTUAL + 1
        OUTPUT
            INSERTED.NUMERO_ACTUAL,
            INSERTED.PREFIJO,
            INSERTED.NUMERO_RESOLUCION,
            INSERTED.FECHA_RESOLUCION,
            INSERTED.FECHA_INICIO_VIGENCIA,
            INSERTED.FECHA_FIN_VIGENCIA,
            INSERTED.RANGO_INICIO,
            INSERTED.RANGO_FIN,
            INSERTED.CLAVE_TECNICA
        INTO @resolucion
        WHERE ACTIVA = 1
          AND TIPO   = 'FC'
          AND CAST(GETDATE() AS DATE) BETWEEN FECHA_INICIO_VIGENCIA AND FECHA_FIN_VIGENCIA
          AND NUMERO_ACTUAL < RANGO_FIN;

        -- Si existe resolución activa, guardar número DIAN y marcar PENDIENTE
        IF EXISTS (SELECT 1 FROM @resolucion)
            UPDATE FACTURAS SET
                NUMERO_FACTURA_DIAN = (SELECT numero_dian FROM @resolucion),
                ESTADO_DIAN         = 'PENDIENTE'
            WHERE ID_FACTURA = @NuevoID;

        SELECT @NuevoID AS ID_INSERTADO;
    END

    -- ----------------------------------------------------------
    ELSE IF (@accion = 'venderProducto')
    BEGIN
        DECLARE @COSTO_UNITARIO_AL_VENDER   DECIMAL(18,2) =
            (SELECT COSTO_X_UNIDAD FROM PRODUCTOS WHERE PRODUCT_ID = @idx_producto);
        DECLARE @PRECIO_UNITARIO_VENTA      DECIMAL(18,2) = @costo_total / @cantidad;
        DECLARE @UTILIDAD_UNITARIA          DECIMAL(18,2) =
            @PRECIO_UNITARIO_VENTA - @COSTO_UNITARIO_AL_VENDER;
        DECLARE @UTILIDAD_TOTAL             DECIMAL(18,2) = @UTILIDAD_UNITARIA * @cantidad;
        DECLARE @gramaje_total_producto     NUMERIC(18,2) =
            (SELECT GRAMAJE_DEL_PRODUCTO FROM PRODUCTOS WHERE PRODUCT_ID = @idx_producto);

        INSERT INTO VENDIDO_PRODUCTOS (
            IDX_FACTURA, IDX_PRODUCTO, QUANTITY, TOTAL_COST,
            VALOR_IVA, SUB_TOTAL,
            COSTO_UNITARIO_AL_VENDER, PRECIO_UNITARIO_VENTA,
            UTILIDAD_UNITARIA, UTILIDAD_TOTAL, GRAMAJE_VENDIDO
        )
        VALUES (
            @id_factura, @idx_producto, @cantidad, @costo_total,
            (@costo_total * @porcentaje_iva),
            @costo_total - (@costo_total * @porcentaje_iva),
            @COSTO_UNITARIO_AL_VENDER, @PRECIO_UNITARIO_VENTA,
            @UTILIDAD_UNITARIA, @UTILIDAD_TOTAL,
            ISNULL(@gramaje_total, 0)
        );

        UPDATE PRODUCTOS SET
            QUANTITY              = QUANTITY - @cantidad,
            GRAMAJE_DEL_PRODUCTO  = ISNULL(@gramaje_total_producto, 0) - ISNULL(@gramaje_total, 0)
        WHERE PRODUCT_ID = @idx_producto;
    END

    -- ----------------------------------------------------------
    ELSE IF (@accion = 'actualizarTotalIva')
    BEGIN
        UPDATE FACTURAS SET
            VALOR_IVA = (SELECT SUM(VALOR_IVA)
                         FROM VENDIDO_PRODUCTOS
                         WHERE IDX_FACTURA = @id_factura)
        WHERE ID_FACTURA = @id_factura;
    END

    -- ----------------------------------------------------------
    ELSE IF (@accion = 'anularFactura')
    BEGIN
        -- 1. Marcar factura como anulada
        UPDATE FACTURAS SET ANULADO = 1, ESTADO_DIAN = 'ANULADA'
        WHERE ID_FACTURA = @id_factura;

        -- 2. Restaurar stock (QUANTITY + GRAMAJE, exactamente inverso a venderProducto)
        UPDATE P SET
            P.QUANTITY             = P.QUANTITY + VP.QUANTITY,
            P.GRAMAJE_DEL_PRODUCTO = P.GRAMAJE_DEL_PRODUCTO + ISNULL(VP.GRAMAJE_VENDIDO, 0)
        FROM PRODUCTOS P
        INNER JOIN VENDIDO_PRODUCTOS VP ON P.PRODUCT_ID = VP.IDX_PRODUCTO
        WHERE VP.IDX_FACTURA = @id_factura;

        -- 3. Revertir saldo del cliente (solo facturas a crédito IDX_FORMA_PAGO = 2)
        UPDATE CLIENTES SET
            SALDO_NEGATIVO = SALDO_NEGATIVO -
                ISNULL((
                    SELECT CASE WHEN IDX_FORMA_PAGO = 2
                                THEN COSTO_TOTAL - ISNULL(VALOR_PAGADO, 0)
                                ELSE 0
                           END
                    FROM FACTURAS WHERE ID_FACTURA = @id_factura
                ), 0)
        WHERE CLIENTE_ID = (SELECT IDX_CLIENTE FROM FACTURAS WHERE ID_FACTURA = @id_factura);
        -- NOTA: VALOR_PAGADO (dinero físico ya recibido) NO se acredita automáticamente.
        -- La devolución en efectivo debe registrarse como movimiento de caja manual.
    END
END
GO


-- ============================================================
-- D.13  SP_CARGADO_FACTURAS — reescritura completa
--       Incluye:
--         • @solo_anuladas (de sp_anulacion.sql)
--         • ANULADO en table0 (de sp_anulacion.sql)
--         • CUFE_FACTURA, NUMERO_FACTURA_DIAN, ESTADO_DIAN,
--           QR_DIAN en table0 (nuevo en fase 0)
-- ============================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SP_CARGADO_FACTURAS]
    @todas          BIT,
    @fechaInicial   DATETIME = NULL,
    @fechaFinal     DATETIME = NULL,
    @cliente        DECIMAL,
    @usuario        DECIMAL,
    @solo_anuladas  BIT      = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        FC.ID_FACTURA,
        FC.COSTO_TOTAL,
        FC.IDX_CLIENTE,
        FC.IDX_USUARIO,
        FP.FORMA_PAGO                                               AS forma_pago,
        FC.IDX_FORMA_PAGO                                           AS medio,
        FORMAT(FC.FECHA_VENTA, 'dd/MM/yyyy hh:mm tt')              AS FECHA_VENTA,
        CONCAT(CL.NOMBRES, ' ', CL.APELLIDOS)                       AS CLIENTE_NOMBRE,
        CL.NUMERO_TELEFONO                                          AS TELEFONO_CLIENTE,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                       AS USUARIO_NOMBRE,
        DP.NUMERO_TELEFONO                                          AS TELEFONO_USUARIO,
        FC.CONSUMIDOR_FINAL,
        FC.VALOR_IVA,
        FC.VALOR_PAGADO                                             AS pagado,
        FC.ANULADO,
        -- Campos DIAN
        FC.CUFE_FACTURA,
        FC.NUMERO_FACTURA_DIAN,
        FC.ESTADO_DIAN,
        FC.QR_DIAN
    INTO #CLIENTES
    FROM FACTURAS FC
    INNER JOIN CLIENTES         CL ON FC.IDX_CLIENTE             = CL.CLIENTE_ID
    INNER JOIN USUARIOS         US ON FC.IDX_USUARIO             = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES DP ON US.IDX_DATOS_PERSONALES    = DP.DATOS_PERSONALES_ID
    INNER JOIN FORMAS_PAGO      FP ON FC.IDX_FORMA_PAGO          = FP.ID_FORMA_PAGO
    WHERE (
            (FC.FECHA_VENTA >= ISNULL(@fechaInicial, FC.FECHA_VENTA)
         AND FC.FECHA_VENTA <= ISNULL(@fechaFinal,   FC.FECHA_VENTA))
         OR @todas = 1
          )
      AND (FC.IDX_USUARIO  = @usuario OR @usuario = 0)
      AND (FC.IDX_CLIENTE  = @cliente OR @cliente = 0)
      AND (
            (@solo_anuladas = 0 AND (FC.ANULADO IS NULL OR FC.ANULADO <> 1))
         OR (@solo_anuladas = 1 AND FC.ANULADO = 1)
          );

    -- Table 0: listado de facturas
    SELECT * FROM #CLIENTES;

    -- Table 1: productos vendidos de las facturas seleccionadas
    SELECT
        VP.IDX_FACTURA,
        VP.QUANTITY,
        VP.TOTAL_COST,
        VP.COSTO_UNITARIO_AL_VENDER                                 AS valor_vendido,
        P.PRODUCTO,
        P.COSTO_X_UNIDAD,
        VP.SUB_TOTAL,
        VP.VALOR_IVA,
        MP.EQUIVALENCIA_MEDIDA,
        CASE MP.IDX_TIPO_MEDIDA
            WHEN 1 THEN ''
            ELSE CASE VP.QUANTITY WHEN 1 THEN 'unidad' ELSE 'unidades' END
        END                                                          AS EQUIVALENCIA,
        VP.GRAMAJE_VENDIDO
    FROM VENDIDO_PRODUCTOS VP
    INNER JOIN PRODUCTOS    P  ON VP.IDX_PRODUCTO = P.PRODUCT_ID
    LEFT  JOIN MEDIDAS_PESADO MP ON P.IDX_MEDIDA  = MP.ID_MEDIDAS_PESADO
    WHERE VP.IDX_FACTURA IN (SELECT ID_FACTURA FROM #CLIENTES);

    -- Table 2: servicios vendidos de las facturas seleccionadas
    SELECT SD.*, S.COSTO_REGULAR, S.SERVICIO
    FROM SERVICIOS_DADOS SD
    INNER JOIN SERVICIOS S ON SD.IDX_SERVICIO = S.SERVICIO_ID
    WHERE SD.IDX_FACTURA IN (SELECT ID_FACTURA FROM #CLIENTES);

    DROP TABLE #CLIENTES;
END
GO
