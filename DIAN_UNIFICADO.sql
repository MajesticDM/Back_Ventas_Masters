-- ============================================================
-- DIAN_UNIFICADO.sql
-- Script unificado DIAN + IVA General — MOTO_MASTERS
-- Generado: 2026-05-31
--
-- Consolida (en orden de dependencia):
--   sp_dian_fase0.sql        — tablas, ALTER, SPs base
--   sp_dian_fase1_fixes.sql  — CLIENTES.DIGITO_VERIFICACION,
--                              FACTURAS.FECHA_VENCIMIENTO,
--                              SP_DIAN_DATOS_FACTURA (reescritura)
--   sp_dian_fase3.sql        — FACTURAS.TRACK_ID_DIAN,
--                              SP_DIAN_OBTENER_XML, SP_DIAN_GUARDAR_TRACK
--   sp_dian_config.sql       — SPs de configuración DIAN
--   sp_dian_reporte.sql      — SP_DIAN_REPORTE_ESTADOS
--   sp_iva_general.sql       — CONFIGURACIONES.BIT_IVA_INCLUIDO,
--                              PRODUCTOS.PORCENTAJE_IVA + TIPO_IMPUESTO,
--                              SP_FACTURAS_ACCIONES (reescritura con IVA por producto),
--                              SP_CARGADO_CONFIGURACION_GENERAL,
--                              SP_GUARDADO_CONFIGURACION_GENERAL,
--                              SP_ACCIONES_PRODUCTOS
--
-- Conflictos resueltos:
--   SP_DIAN_DATOS_FACTURA  → versión fase1 (más completa: DV adquirente,
--                            fecha vencimiento, prepago, maneja_credito)
--   SP_FACTURAS_ACCIONES   → versión iva_general (más completa: IVA por
--                            producto con BIT_IVA_INCLUIDO + fallback global)
--
-- Seguro re-ejecutar: CREATE OR ALTER en SPs;
--                     IF COL_LENGTH / IF NOT EXISTS en DDL.
-- ============================================================


-- ============================================================
-- SECCIÓN 1 — TABLAS NUEVAS
-- ============================================================

-- ------------------------------------------------------------
-- 1.1  RESOLUCIONES_DIAN
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'RESOLUCIONES_DIAN')
BEGIN
    CREATE TABLE [dbo].[RESOLUCIONES_DIAN] (
        [ID_RESOLUCION]         NUMERIC(18,0) IDENTITY(1,1) NOT NULL,
        [NUMERO_RESOLUCION]     VARCHAR(20)   NOT NULL,
        [FECHA_RESOLUCION]      DATE          NOT NULL,
        [FECHA_INICIO_VIGENCIA] DATE          NOT NULL,
        [FECHA_FIN_VIGENCIA]    DATE          NOT NULL,
        [PREFIJO]               VARCHAR(10)   NULL,
        [RANGO_INICIO]          NUMERIC(18,0) NOT NULL,
        [RANGO_FIN]             NUMERIC(18,0) NOT NULL,
        [NUMERO_ACTUAL]         NUMERIC(18,0) NOT NULL DEFAULT 0,
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

-- ------------------------------------------------------------
-- 1.2  TIPOS_IVA
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'TIPOS_IVA')
BEGIN
    CREATE TABLE [dbo].[TIPOS_IVA] (
        [ID_TIPO_IVA]    NUMERIC(18,0) IDENTITY(1,1) NOT NULL,
        [DESCRIPCION]    VARCHAR(100)  NOT NULL,
        [PORCENTAJE]     NUMERIC(5,2)  NOT NULL,
        [CODIGO_TRIBUTO] VARCHAR(10)   NOT NULL,  -- '01'=IVA, 'ZZ'=No causa
        [NOMBRE_TRIBUTO] VARCHAR(50)   NOT NULL,  -- 'IVA', 'No causa', etc.
        [ACTIVO]         BIT           NOT NULL DEFAULT 1,
        CONSTRAINT [PK_TIPOS_IVA] PRIMARY KEY CLUSTERED ([ID_TIPO_IVA] ASC)
    );
    PRINT 'Tabla TIPOS_IVA creada.';
END
ELSE
    PRINT 'Tabla TIPOS_IVA ya existe — omitida.';
GO


-- ============================================================
-- SECCIÓN 2 — ALTER TABLE (idempotente)
-- ============================================================

-- ------------------------------------------------------------
-- 2.1  FACTURAS
--      Fuentes: fase0 (base) + fase1 (FECHA_VENCIMIENTO)
--               + fase3 (TRACK_ID_DIAN)
-- ------------------------------------------------------------
IF COL_LENGTH('FACTURAS', 'NUMERO_FACTURA_DIAN') IS NULL
    ALTER TABLE FACTURAS ADD [NUMERO_FACTURA_DIAN] NUMERIC(18,0) NULL;
GO
IF COL_LENGTH('FACTURAS', 'ESTADO_DIAN') IS NULL
    ALTER TABLE FACTURAS ADD [ESTADO_DIAN] VARCHAR(20) NULL; -- PENDIENTE|VALIDADA|RECHAZADA|CONTINGENCIA|ANULADA
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
IF COL_LENGTH('FACTURAS', 'FECHA_VENCIMIENTO') IS NULL
    ALTER TABLE FACTURAS ADD [FECHA_VENCIMIENTO] DATE NULL;
GO
IF COL_LENGTH('FACTURAS', 'TRACK_ID_DIAN') IS NULL
    ALTER TABLE FACTURAS ADD [TRACK_ID_DIAN] VARCHAR(100) NULL;
GO

-- ------------------------------------------------------------
-- 2.2  CONFIGURACIONES
--      Fuentes: fase0 (campos DIAN emisor)
--               + iva_general (BIT_IVA_INCLUIDO)
-- ------------------------------------------------------------
IF COL_LENGTH('CONFIGURACIONES', 'NOMBRE_COMERCIAL') IS NULL
    ALTER TABLE CONFIGURACIONES ADD [NOMBRE_COMERCIAL] VARCHAR(200) NULL;
GO
IF COL_LENGTH('CONFIGURACIONES', 'DIGITO_VERIFICACION') IS NULL
    ALTER TABLE CONFIGURACIONES ADD [DIGITO_VERIFICACION] VARCHAR(2) NULL;
GO
IF COL_LENGTH('CONFIGURACIONES', 'MUNICIPIO_DIAN') IS NULL
    ALTER TABLE CONFIGURACIONES ADD [MUNICIPIO_DIAN] VARCHAR(10) NULL;
GO
IF COL_LENGTH('CONFIGURACIONES', 'DEPARTAMENTO_DIAN') IS NULL
    ALTER TABLE CONFIGURACIONES ADD [DEPARTAMENTO_DIAN] VARCHAR(10) NULL;
GO
IF COL_LENGTH('CONFIGURACIONES', 'CODIGO_POSTAL') IS NULL
    ALTER TABLE CONFIGURACIONES ADD [CODIGO_POSTAL] VARCHAR(10) NULL;
GO
IF COL_LENGTH('CONFIGURACIONES', 'IDX_TIPO_DOCUMENTO_EMPRESA') IS NULL
    ALTER TABLE CONFIGURACIONES ADD [IDX_TIPO_DOCUMENTO_EMPRESA] NUMERIC(18,0) NULL;
GO
IF COL_LENGTH('CONFIGURACIONES', 'IDX_REGIMEN_TRIBUTARIO_EMPRESA') IS NULL
    ALTER TABLE CONFIGURACIONES ADD [IDX_REGIMEN_TRIBUTARIO_EMPRESA] NUMERIC(18,0) NULL;
GO
IF COL_LENGTH('CONFIGURACIONES', 'IDX_RESPONSABILIDAD_FISCAL_EMPRESA') IS NULL
    ALTER TABLE CONFIGURACIONES ADD [IDX_RESPONSABILIDAD_FISCAL_EMPRESA] NUMERIC(18,0) NULL;
GO
IF COL_LENGTH('CONFIGURACIONES', 'SOFTWARE_ID_DIAN') IS NULL
    ALTER TABLE CONFIGURACIONES ADD [SOFTWARE_ID_DIAN] VARCHAR(100) NULL;
GO
IF COL_LENGTH('CONFIGURACIONES', 'SOFTWARE_PIN_DIAN') IS NULL
    ALTER TABLE CONFIGURACIONES ADD [SOFTWARE_PIN_DIAN] VARCHAR(50) NULL;
GO
IF COL_LENGTH('CONFIGURACIONES', 'AMBIENTE_DIAN') IS NULL
    ALTER TABLE CONFIGURACIONES ADD [AMBIENTE_DIAN] TINYINT NULL DEFAULT 2; -- 1=Producción, 2=Habilitación
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('CONFIGURACIONES') AND name = 'BIT_IVA_INCLUIDO'
)
    ALTER TABLE CONFIGURACIONES ADD BIT_IVA_INCLUIDO BIT NOT NULL DEFAULT 1;
GO

-- ------------------------------------------------------------
-- 2.3  PRODUCTOS
--      Fuentes: fase0 (CODIGO_UNSPSC, IDX_TIPO_IVA)
--               + iva_general (PORCENTAJE_IVA, TIPO_IMPUESTO)
-- ------------------------------------------------------------
IF COL_LENGTH('PRODUCTOS', 'CODIGO_UNSPSC') IS NULL
    ALTER TABLE PRODUCTOS ADD [CODIGO_UNSPSC] VARCHAR(15) NULL;
GO
IF COL_LENGTH('PRODUCTOS', 'IDX_TIPO_IVA') IS NULL
    ALTER TABLE PRODUCTOS ADD [IDX_TIPO_IVA] NUMERIC(18,0) NULL;
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('PRODUCTOS') AND name = 'PORCENTAJE_IVA'
)
    ALTER TABLE PRODUCTOS ADD PORCENTAJE_IVA NUMERIC(18,2) NULL;
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('PRODUCTOS') AND name = 'TIPO_IMPUESTO'
)
    ALTER TABLE PRODUCTOS ADD TIPO_IMPUESTO VARCHAR(20) NULL;
GO

-- ------------------------------------------------------------
-- 2.4  CLIENTES
--      Fuentes: fase0 (MUNICIPIO_DIAN, CODIGO_POSTAL)
--               + fase1 (DIGITO_VERIFICACION)
-- ------------------------------------------------------------
IF COL_LENGTH('CLIENTES', 'MUNICIPIO_DIAN') IS NULL
    ALTER TABLE CLIENTES ADD [MUNICIPIO_DIAN] VARCHAR(10) NULL;
GO
IF COL_LENGTH('CLIENTES', 'CODIGO_POSTAL') IS NULL
    ALTER TABLE CLIENTES ADD [CODIGO_POSTAL] VARCHAR(10) NULL;
GO
IF COL_LENGTH('CLIENTES', 'DIGITO_VERIFICACION') IS NULL
    ALTER TABLE CLIENTES ADD [DIGITO_VERIFICACION] VARCHAR(2) NULL;
GO

-- ------------------------------------------------------------
-- 2.5  FORMAS_PAGO
--      Fuente: fase0
-- ------------------------------------------------------------
IF COL_LENGTH('FORMAS_PAGO', 'CODIGO_MEDIO_PAGO_DIAN') IS NULL
    ALTER TABLE FORMAS_PAGO ADD [CODIGO_MEDIO_PAGO_DIAN] VARCHAR(5) NULL;
    -- Códigos comunes: 10=Efectivo 20=Cheque 30=Crédito
    -- 42=Consignación 48=Tarjeta crédito 49=Tarjeta débito ZZZ=Otro
GO


-- ============================================================
-- SECCIÓN 3 — DATOS INICIALES
-- ============================================================

-- ------------------------------------------------------------
-- 3.1  Seed TIPOS_IVA (idempotente)
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM TIPOS_IVA)
BEGIN
    INSERT INTO TIPOS_IVA (DESCRIPCION, PORCENTAJE, CODIGO_TRIBUTO, NOMBRE_TRIBUTO) VALUES
    ('IVA 19%',  19.00, '01', 'IVA'),
    ('IVA 5%',    5.00, '01', 'IVA'),
    ('Exento',    0.00, '01', 'IVA'),     -- aplica IVA a tarifa 0%
    ('Excluido',  0.00, 'ZZ', 'No causa'); -- no sujeto a IVA
    PRINT 'TIPOS_IVA: 4 registros insertados.';
END
ELSE
    PRINT 'TIPOS_IVA ya tiene datos — seed omitido.';
GO


-- ============================================================
-- SECCIÓN 4 — STORED PROCEDURES
-- ============================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ------------------------------------------------------------
-- 4.1  SP_DIAN_SIGUIENTE_NUMERO
--      Obtiene y reserva atómicamente el siguiente número
--      consecutivo de la resolución activa del tipo indicado.
--      Retorna NULL si no hay resolución activa o rango agotado.
--      Fuente: sp_dian_fase0.sql
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_DIAN_SIGUIENTE_NUMERO]
    @tipo VARCHAR(2) = 'FC'  -- FC | NC | ND
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @captura TABLE (
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

-- ------------------------------------------------------------
-- 4.2  SP_DIAN_ACTUALIZAR_ESTADO
--      Persiste el resultado del proceso DIAN en la factura.
--      Solo actualiza los parámetros no-nulos (puede llamarse
--      dos veces: una al firmar XML y otra al recibir respuesta).
--      Fuente: sp_dian_fase0.sql
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_DIAN_ACTUALIZAR_ESTADO]
    @id_factura  NUMERIC(18,0),
    @cufe        VARCHAR(1000) = NULL,
    @estado_dian VARCHAR(20)   = NULL, -- PENDIENTE|VALIDADA|RECHAZADA|CONTINGENCIA
    @qr_dian     VARCHAR(500)  = NULL,
    @xml_dian    VARCHAR(MAX)  = NULL,
    @notas_dian  VARCHAR(1000) = NULL
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

-- ------------------------------------------------------------
-- 4.3  SP_DIAN_DATOS_FACTURA
--      Payload completo para construir el XML UBL 2.1 y calcular
--      el CUFE. 4 result sets: cabecera, líneas producto,
--      líneas servicio, subtotales impuestos.
--      Fuente: sp_dian_fase1_fixes.sql (versión más completa:
--              incluye adquirente_digito_verificacion,
--              fecha_vencimiento_dian, prepago, maneja_credito)
-- ------------------------------------------------------------
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
        FORMAT(F.FECHA_VENTA, 'yyyyMMdd')            AS fecha_dian,
        FORMAT(F.FECHA_VENTA, 'HH:mm:ss')
            + '-05:00'                               AS hora_dian,
        F.COSTO_TOTAL                                AS total,
        ISNULL(F.VALOR_IVA, 0)                       AS total_iva,
        F.COSTO_TOTAL - ISNULL(F.VALOR_IVA, 0)      AS subtotal,
        F.CONSUMIDOR_FINAL,
        -- Fecha de vencimiento para PaymentMeans/DueDate:
        --   1) Explícita si fue capturada al crear la factura
        --   2) +30 días para crédito
        --   3) Misma fecha para contado
        CASE
            WHEN F.FECHA_VENCIMIENTO IS NOT NULL
                THEN F.FECHA_VENCIMIENTO
            WHEN FP.MANEJA_CREDITO = 1
                THEN DATEADD(DAY, 30, CAST(F.FECHA_VENTA AS DATE))
            ELSE CAST(F.FECHA_VENTA AS DATE)
        END                                          AS fecha_vencimiento_dian,
        FP.MANEJA_CREDITO,
        F.PAGO_INICIAL                               AS prepago,
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
        ISNULL(RT_E.EQUIVALENCIA_REGIMEN_TRIBUTARIO, 'ZZ')      AS emisor_regimen,
        ISNULL(RF_E.EQUIVALENCIA_RESPONSABILIDAD,    'R-99-PN') AS emisor_responsabilidad,
        ISNULL(TD_E.EQUIVALENCIA_TIPO,               '31')      AS emisor_tipo_documento,
        -- Adquirente (cliente)
        CONCAT(CL.NOMBRES, ' ', CL.APELLIDOS)        AS adquirente_nombre,
        CL.IDENTIFICACION                            AS adquirente_identificacion,
        ISNULL(CL.DIGITO_VERIFICACION, '0')          AS adquirente_digito_verificacion,
        ISNULL(CL.CORREO_ELECTRONICO, '')            AS adquirente_email,
        CL.NUMERO_TELEFONO                           AS adquirente_telefono,
        ISNULL(CL.DIRECCION_FISCAL, 'No registrada') AS adquirente_direccion,
        ISNULL(CL.MUNICIPIO_DIAN,   '11001')         AS adquirente_municipio,
        ISNULL(CL.CODIGO_POSTAL,    '110111')        AS adquirente_codigo_postal,
        ISNULL(TD_C.EQUIVALENCIA_TIPO,    '13')      AS adquirente_tipo_documento,
        ISNULL(RT_C.EQUIVALENCIA_REGIMEN_TRIBUTARIO, 'ZZ')      AS adquirente_regimen,
        ISNULL(RF_C.EQUIVALENCIA_RESPONSABILIDAD,    'R-99-PN') AS adquirente_responsabilidad,
        -- Resolución activa FC
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
        CASE WHEN FP.MANEJA_CREDITO = 1 THEN 'Crédito' ELSE 'Contado' END AS tipo_pago_dian
    FROM FACTURAS F
    INNER JOIN CLIENTES              CL   ON F.IDX_CLIENTE    = CL.CLIENTE_ID
    CROSS JOIN CONFIGURACIONES       CF
    INNER JOIN FORMAS_PAGO           FP   ON F.IDX_FORMA_PAGO = FP.ID_FORMA_PAGO
    LEFT JOIN  RESOLUCIONES_DIAN     RD
           ON  RD.ACTIVA = 1
          AND  RD.TIPO   = 'FC'
          AND  CAST(F.FECHA_VENTA AS DATE)
               BETWEEN RD.FECHA_INICIO_VIGENCIA AND RD.FECHA_FIN_VIGENCIA
    LEFT JOIN REGIMENES_TRIBUTARIOS      RT_E ON CF.IDX_REGIMEN_TRIBUTARIO_EMPRESA      = RT_E.ID_REGIMEN_TRIBUTARIO
    LEFT JOIN RESPONSABILIDADES_FISCALES RF_E ON CF.IDX_RESPONSABILIDAD_FISCAL_EMPRESA  = RF_E.ID_RESPONSABILIDAD_FISCAL
    LEFT JOIN TIPO_DOCUMENTO             TD_E ON CF.IDX_TIPO_DOCUMENTO_EMPRESA          = TD_E.ID_TIPO_DOCUMENTO
    LEFT JOIN REGIMENES_TRIBUTARIOS      RT_C ON CL.IDX_REGIMEN_TRIBUTARIO              = RT_C.ID_REGIMEN_TRIBUTARIO
    LEFT JOIN RESPONSABILIDADES_FISCALES RF_C ON CL.IDX_RESPONSABILIDAD_FISCAL         = RF_C.ID_RESPONSABILIDAD_FISCAL
    LEFT JOIN TIPO_DOCUMENTO             TD_C ON CL.IDX_TIPO_DOCUMENTO                 = TD_C.ID_TIPO_DOCUMENTO
    WHERE F.ID_FACTURA = @id_factura;

    -- ----------------------------------------------------------
    -- Resultado 1: Líneas de productos
    -- ----------------------------------------------------------
    SELECT
        ROW_NUMBER() OVER (ORDER BY VP.ID_VENDIDO_PRODUCT) AS numero_linea,
        P.PRODUCTO                                          AS descripcion,
        P.CODIGO_BARRAS                                     AS codigo_vendedor,
        ISNULL(P.CODIGO_UNSPSC, '25172000')                 AS codigo_unspsc,
        VP.QUANTITY                                         AS cantidad,
        ISNULL(MP.EQUIVALENCIA_MEDIDA, 'EA')                AS unidad_medida,
        VP.PRECIO_UNITARIO_VENTA                            AS precio_unitario,
        VP.SUB_TOTAL                                        AS subtotal_linea,
        ISNULL(TI.PORCENTAJE,     19.00)                    AS porcentaje_iva,
        ISNULL(TI.CODIGO_TRIBUTO, '01')                     AS codigo_tributo,
        ISNULL(TI.NOMBRE_TRIBUTO, 'IVA')                    AS nombre_tributo,
        VP.VALOR_IVA                                        AS valor_iva_linea,
        VP.TOTAL_COST                                       AS total_linea,
        VP.GRAMAJE_VENDIDO
    FROM VENDIDO_PRODUCTOS VP
    INNER JOIN PRODUCTOS      P  ON VP.IDX_PRODUCTO = P.PRODUCT_ID
    LEFT  JOIN TIPOS_IVA      TI ON P.IDX_TIPO_IVA  = TI.ID_TIPO_IVA
    LEFT  JOIN MEDIDAS_PESADO MP ON P.IDX_MEDIDA    = MP.ID_MEDIDAS_PESADO
    WHERE VP.IDX_FACTURA = @id_factura;

    -- ----------------------------------------------------------
    -- Resultado 2: Líneas de servicios
    --   '80111500' = Management support services (UNSPSC default)
    -- ----------------------------------------------------------
    SELECT
        ROW_NUMBER() OVER (ORDER BY SD.SERVICIO_DADOS_ID) AS numero_linea,
        S.SERVICIO                                          AS descripcion,
        '80111500'                                          AS codigo_unspsc,
        1                                                   AS cantidad,
        'ZZ'                                                AS unidad_medida,
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
    -- ----------------------------------------------------------
    SELECT
        ISNULL(TI.CODIGO_TRIBUTO, '01')  AS codigo_tributo,
        ISNULL(TI.NOMBRE_TRIBUTO, 'IVA') AS nombre_tributo,
        ISNULL(TI.PORCENTAJE,     19.00) AS porcentaje,
        SUM(VP.SUB_TOTAL)                AS base_gravable,
        SUM(VP.VALOR_IVA)                AS valor_impuesto
    FROM VENDIDO_PRODUCTOS VP
    INNER JOIN PRODUCTOS P  ON VP.IDX_PRODUCTO = P.PRODUCT_ID
    LEFT  JOIN TIPOS_IVA TI ON P.IDX_TIPO_IVA  = TI.ID_TIPO_IVA
    WHERE VP.IDX_FACTURA = @id_factura
    GROUP BY TI.CODIGO_TRIBUTO, TI.NOMBRE_TRIBUTO, TI.PORCENTAJE;
END
GO

-- ------------------------------------------------------------
-- 4.4  SP_FACTURAS_ACCIONES
--      Fuente: sp_iva_general.sql (versión más completa).
--      Diferencias vs fase0:
--        • venderProducto: IVA por producto con fallback a IVA
--          global + lógica BIT_IVA_INCLUIDO (incluido/excluido)
--        • crearFactura y anularFactura: idénticos a fase0
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_FACTURAS_ACCIONES]
    @accion             VARCHAR(100),
    @id_factura         NUMERIC(18,0) = NULL,
    @idx_cliente        NUMERIC(18,0) = NULL,
    @idx_usuario        NUMERIC(18,0) = NULL,
    @costo_total        NUMERIC(18,2) = NULL,
    @estado             BIT           = NULL,
    @consumidor_final   BIT           = NULL,
    @cufe_factura       VARCHAR(1000) = NULL,
    @idx_producto       NUMERIC(18,0) = NULL,
    @cantidad           NUMERIC(18,2) = NULL,
    @forma_pago         NUMERIC(18,0) = NULL,
    @forma_pago_inicial NUMERIC(18,0) = 0,
    @pago_inicial       NUMERIC(18,2) = NULL,
    @usa_saldo_favor    BIT           = NULL,
    @gramaje_total      NUMERIC(18,2) = NULL
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
                SET @pago_inicial   = @disponible;
                SET @saldo_favor    = 0;
                SET @saldo_negativo = @saldo_negativo + (@costo_total - @pago_inicial);
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
        DECLARE @COSTO_UNITARIO_AL_VENDER DECIMAL(18,2) =
            (SELECT COSTO_X_UNIDAD FROM PRODUCTOS WHERE PRODUCT_ID = @idx_producto);
        DECLARE @PRECIO_UNITARIO_VENTA    DECIMAL(18,2) = @costo_total / @cantidad;
        DECLARE @UTILIDAD_UNITARIA        DECIMAL(18,2) =
            @PRECIO_UNITARIO_VENTA - @COSTO_UNITARIO_AL_VENDER;
        DECLARE @UTILIDAD_TOTAL           DECIMAL(18,2) = @UTILIDAD_UNITARIA * @cantidad;
        DECLARE @gramaje_total_producto   NUMERIC(18,2) =
            (SELECT GRAMAJE_DEL_PRODUCTO FROM PRODUCTOS WHERE PRODUCT_ID = @idx_producto);

        -- IVA: primero busca en el producto; si es 0 usa config global
        DECLARE @pct_producto NUMERIC(18,2) =
            ISNULL((SELECT PORCENTAJE_IVA FROM PRODUCTOS WHERE PRODUCT_ID = @idx_producto), 0);
        DECLARE @pct_efectivo NUMERIC(18,2) =
            CASE WHEN @pct_producto > 0 THEN @pct_producto ELSE @porcentaje_iva END;
        DECLARE @bit_incluido BIT =
            ISNULL((SELECT TOP 1 BIT_IVA_INCLUIDO FROM CONFIGURACIONES), 1);

        DECLARE @valor_iva  NUMERIC(18,2) = @costo_total * @pct_efectivo;
        DECLARE @sub_total  NUMERIC(18,2);
        DECLARE @total_real NUMERIC(18,2);

        IF @bit_incluido = 1
        BEGIN
            -- IVA ya está en el precio: extraerlo
            SET @sub_total  = @costo_total - @valor_iva;
            SET @total_real = @costo_total;
        END
        ELSE
        BEGIN
            -- IVA no está en el precio: sumarlo
            SET @sub_total  = @costo_total;
            SET @total_real = @costo_total + @valor_iva;
        END

        INSERT INTO VENDIDO_PRODUCTOS (
            IDX_FACTURA, IDX_PRODUCTO, QUANTITY, TOTAL_COST,
            VALOR_IVA, SUB_TOTAL,
            COSTO_UNITARIO_AL_VENDER, PRECIO_UNITARIO_VENTA,
            UTILIDAD_UNITARIA, UTILIDAD_TOTAL, GRAMAJE_VENDIDO
        )
        VALUES (
            @id_factura, @idx_producto, @cantidad, @total_real,
            @valor_iva, @sub_total,
            @COSTO_UNITARIO_AL_VENDER, @PRECIO_UNITARIO_VENTA,
            @UTILIDAD_UNITARIA, @UTILIDAD_TOTAL,
            ISNULL(@gramaje_total, 0)
        );

        UPDATE PRODUCTOS SET
            QUANTITY             = QUANTITY - @cantidad,
            GRAMAJE_DEL_PRODUCTO = ISNULL(@gramaje_total_producto, 0) - ISNULL(@gramaje_total, 0)
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

        -- 2. Restaurar stock (inverso exacto a venderProducto)
        UPDATE P SET
            P.QUANTITY             = P.QUANTITY + VP.QUANTITY,
            P.GRAMAJE_DEL_PRODUCTO = P.GRAMAJE_DEL_PRODUCTO + ISNULL(VP.GRAMAJE_VENDIDO, 0)
        FROM PRODUCTOS P
        INNER JOIN VENDIDO_PRODUCTOS VP ON P.PRODUCT_ID = VP.IDX_PRODUCTO
        WHERE VP.IDX_FACTURA = @id_factura;

        -- 3. Revertir saldo del cliente (solo facturas a crédito)
        --    VALOR_PAGADO (efectivo ya recibido) NO se acredita automáticamente;
        --    la devolución en efectivo debe registrarse como movimiento de caja manual.
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
    END
END
GO

-- ------------------------------------------------------------
-- 4.5  SP_CARGADO_FACTURAS
--      Incluye: @solo_anuladas, ANULADO y campos DIAN en table0.
--      Fuente: sp_dian_fase0.sql
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_CARGADO_FACTURAS]
    @todas         BIT,
    @fechaInicial  DATETIME = NULL,
    @fechaFinal    DATETIME = NULL,
    @cliente       DECIMAL,
    @usuario       DECIMAL,
    @solo_anuladas BIT      = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        FC.ID_FACTURA,
        FC.COSTO_TOTAL,
        FC.IDX_CLIENTE,
        FC.IDX_USUARIO,
        FP.FORMA_PAGO                                          AS forma_pago,
        FC.IDX_FORMA_PAGO                                      AS medio,
        FORMAT(FC.FECHA_VENTA, 'dd/MM/yyyy hh:mm tt')         AS FECHA_VENTA,
        CONCAT(CL.NOMBRES, ' ', CL.APELLIDOS)                  AS CLIENTE_NOMBRE,
        CL.NUMERO_TELEFONO                                     AS TELEFONO_CLIENTE,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                  AS USUARIO_NOMBRE,
        DP.NUMERO_TELEFONO                                     AS TELEFONO_USUARIO,
        FC.CONSUMIDOR_FINAL,
        FC.VALOR_IVA,
        FC.VALOR_PAGADO                                        AS pagado,
        FC.ANULADO,
        -- Campos DIAN
        FC.CUFE_FACTURA,
        FC.NUMERO_FACTURA_DIAN,
        FC.ESTADO_DIAN,
        FC.QR_DIAN
    INTO #CLIENTES
    FROM FACTURAS FC
    INNER JOIN CLIENTES         CL ON FC.IDX_CLIENTE          = CL.CLIENTE_ID
    INNER JOIN USUARIOS         US ON FC.IDX_USUARIO          = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES DP ON US.IDX_DATOS_PERSONALES = DP.DATOS_PERSONALES_ID
    INNER JOIN FORMAS_PAGO      FP ON FC.IDX_FORMA_PAGO       = FP.ID_FORMA_PAGO
    WHERE (
            (FC.FECHA_VENTA >= ISNULL(@fechaInicial, FC.FECHA_VENTA)
         AND FC.FECHA_VENTA <= ISNULL(@fechaFinal,   FC.FECHA_VENTA))
         OR @todas = 1
          )
      AND (FC.IDX_USUARIO = @usuario OR @usuario = 0)
      AND (FC.IDX_CLIENTE = @cliente OR @cliente = 0)
      AND (
            (@solo_anuladas = 0 AND (FC.ANULADO IS NULL OR FC.ANULADO <> 1))
         OR (@solo_anuladas = 1 AND FC.ANULADO = 1)
          );

    -- Table 0: listado de facturas
    SELECT * FROM #CLIENTES;

    -- Table 1: productos vendidos
    SELECT
        VP.IDX_FACTURA,
        VP.QUANTITY,
        VP.TOTAL_COST,
        VP.COSTO_UNITARIO_AL_VENDER                            AS valor_vendido,
        P.PRODUCTO,
        P.COSTO_X_UNIDAD,
        VP.SUB_TOTAL,
        VP.VALOR_IVA,
        MP.EQUIVALENCIA_MEDIDA,
        CASE MP.IDX_TIPO_MEDIDA
            WHEN 1 THEN ''
            ELSE CASE VP.QUANTITY WHEN 1 THEN 'unidad' ELSE 'unidades' END
        END                                                     AS EQUIVALENCIA,
        VP.GRAMAJE_VENDIDO
    FROM VENDIDO_PRODUCTOS VP
    INNER JOIN PRODUCTOS    P  ON VP.IDX_PRODUCTO = P.PRODUCT_ID
    LEFT  JOIN MEDIDAS_PESADO MP ON P.IDX_MEDIDA  = MP.ID_MEDIDAS_PESADO
    WHERE VP.IDX_FACTURA IN (SELECT ID_FACTURA FROM #CLIENTES);

    -- Table 2: servicios vendidos
    SELECT SD.*, S.COSTO_REGULAR, S.SERVICIO
    FROM SERVICIOS_DADOS SD
    INNER JOIN SERVICIOS S ON SD.IDX_SERVICIO = S.SERVICIO_ID
    WHERE SD.IDX_FACTURA IN (SELECT ID_FACTURA FROM #CLIENTES);

    DROP TABLE #CLIENTES;
END
GO

-- ------------------------------------------------------------
-- 4.6  SP_BALANCE_DIARIO_IMPRIMIBLE
--      Detalle de movimientos en rango libre (6 result sets).
--      Fuente: sp_dian_fase0.sql
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_BALANCE_DIARIO_IMPRIMIBLE]
    @fecha_inicio DATETIME,
    @fecha_fin    DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    -- Resultado 1: Ventas (Facturas)
    SELECT
        F.ID_FACTURA                                           AS id_factura,
        FORMAT(F.FECHA_VENTA, 'dd/MM/yyyy HH:mm')             AS fecha_venta,
        CONCAT(CL.NOMBRES, ' ', CL.APELLIDOS)                 AS cliente,
        FP.FORMA_PAGO                                         AS forma_pago,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                 AS vendedor,
        F.COSTO_TOTAL                                         AS total,
        F.VALOR_PAGADO                                        AS pagado,
        CASE WHEN F.IDX_FORMA_PAGO = 2
             THEN F.COSTO_TOTAL - F.VALOR_PAGADO
             ELSE 0 END                                       AS pendiente,
        ISNULL(UP.utilidad_factura, 0)                        AS utilidad_total
    FROM FACTURAS F
    INNER JOIN CLIENTES         CL ON F.IDX_CLIENTE           = CL.CLIENTE_ID
    INNER JOIN USUARIOS         US ON F.IDX_USUARIO           = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES DP ON US.IDX_DATOS_PERSONALES = DP.DATOS_PERSONALES_ID
    INNER JOIN FORMAS_PAGO      FP ON F.IDX_FORMA_PAGO        = FP.ID_FORMA_PAGO
    LEFT JOIN (
        SELECT IDX_FACTURA, SUM(UTILIDAD_TOTAL) AS utilidad_factura
        FROM VENDIDO_PRODUCTOS
        GROUP BY IDX_FACTURA
    ) UP ON F.ID_FACTURA = UP.IDX_FACTURA
    WHERE F.FECHA_VENTA BETWEEN @fecha_inicio AND @fecha_fin
    ORDER BY F.FECHA_VENTA;

    -- Resultado 2: Compras
    SELECT
        C.ID_COMPRA                                           AS id_compra,
        FORMAT(C.FECHA_COMPRA, 'dd/MM/yyyy HH:mm')           AS fecha_compra,
        PV.RAZON_SOCIAL                                       AS proveedor,
        FP.FORMA_PAGO                                         AS forma_pago,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                 AS comprador,
        C.COSTO_TOTAL                                         AS total,
        C.VALOR_PAGADO                                        AS pagado,
        C.COSTO_TOTAL - C.VALOR_PAGADO                        AS pendiente
    FROM COMPRAS C
    INNER JOIN PROVEEDORES      PV ON C.IDX_PROVEEDOR           = PV.ID_PROVEEDOR
    INNER JOIN USUARIOS         US ON C.IDX_USUARIO_COMPRADOR   = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES DP ON US.IDX_DATOS_PERSONALES   = DP.DATOS_PERSONALES_ID
    INNER JOIN FORMAS_PAGO      FP ON C.IDX_FORMA_PAGO          = FP.ID_FORMA_PAGO
    WHERE C.FECHA_COMPRA BETWEEN @fecha_inicio AND @fecha_fin
    ORDER BY C.FECHA_COMPRA;

    -- Resultado 3: Gastos (egresos de caja IDX_TIPO_MOVIMIENTO = 2)
    SELECT
        FORMAT(MC.FECHA_MOVIMIENTO, 'dd/MM/yyyy HH:mm')       AS fecha,
        CASE
            WHEN MC.IDX_GASTO IS NULL OR MC.IDX_GASTO = 0
            THEN 'Sin categoria'
            ELSE G.NOMBRE
        END                                                    AS categoria_gasto,
        ISNULL(MC.DESCRIPCION, '')                             AS descripcion,
        FP.FORMA_PAGO                                          AS forma_pago,
        MC.VALOR                                               AS valor
    FROM MOVIMIENTOS_CAJA MC
    LEFT  JOIN GASTOS      G  ON MC.IDX_GASTO        = G.ID_GASTO
    INNER JOIN FORMAS_PAGO FP ON MC.IDX_DENOMINACION = FP.ID_FORMA_PAGO
    WHERE MC.IDX_TIPO_MOVIMIENTO = 2
      AND MC.FECHA_MOVIMIENTO BETWEEN @fecha_inicio AND @fecha_fin
    ORDER BY MC.FECHA_MOVIMIENTO;

    -- Resultado 4: Abonos recibidos de clientes
    SELECT
        FORMAT(DAV.FECHA_ABONO, 'dd/MM/yyyy HH:mm')           AS fecha_abono,
        DAV.IDX_FACTURA                                        AS id_factura,
        CONCAT(CL.NOMBRES, ' ', CL.APELLIDOS)                 AS cliente,
        ISNULL(FP.FORMA_PAGO, 'N/A')                          AS forma_pago,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                 AS usuario,
        DAV.VALOR_ABONADO                                      AS valor_abonado
    FROM DETALLE_ABONOS_VENTAS DAV
    INNER JOIN CLIENTES         CL ON DAV.IDX_CLIENTE         = CL.CLIENTE_ID
    INNER JOIN USUARIOS         US ON DAV.IDX_USUARIO         = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES DP ON US.IDX_DATOS_PERSONALES = DP.DATOS_PERSONALES_ID
    LEFT  JOIN FORMAS_PAGO      FP ON DAV.IDX_FORMA_PAGO      = FP.ID_FORMA_PAGO
    WHERE DAV.FECHA_ABONO BETWEEN @fecha_inicio AND @fecha_fin
    ORDER BY DAV.FECHA_ABONO;

    -- Resultado 5: Abonos pagados a proveedores
    SELECT
        FORMAT(DAC.FECHA_ABONO, 'dd/MM/yyyy HH:mm')           AS fecha_abono,
        DAC.IDX_COMPRA                                         AS id_compra,
        PV.RAZON_SOCIAL                                        AS proveedor,
        ISNULL(FP.FORMA_PAGO, 'N/A')                          AS forma_pago,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                 AS usuario,
        DAC.VALOR_ABONADO                                      AS valor_abonado
    FROM DETALLE_ABONOS_COMPRAS DAC
    INNER JOIN COMPRAS           C  ON DAC.IDX_COMPRA          = C.ID_COMPRA
    INNER JOIN PROVEEDORES       PV ON C.IDX_PROVEEDOR         = PV.ID_PROVEEDOR
    INNER JOIN USUARIOS          US ON DAC.IDX_USUARIO         = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES  DP ON US.IDX_DATOS_PERSONALES = DP.DATOS_PERSONALES_ID
    LEFT  JOIN FORMAS_PAGO       FP ON DAC.IDX_FORMA_PAGO      = FP.ID_FORMA_PAGO
    WHERE DAC.FECHA_ABONO BETWEEN @fecha_inicio AND @fecha_fin
    ORDER BY DAC.FECHA_ABONO;

    -- Resultado 6: Resumen de productos vendidos en el rango
    SELECT
        P.CODIGO_BARRAS                                        AS codigo,
        P.PRODUCTO                                             AS nombre,
        P.COSTO_X_UNIDAD                                       AS costo_actual,
        SUM(VP.QUANTITY)                                       AS cantidad_vendida,
        SUM(VP.TOTAL_COST)                                     AS ingresos,
        SUM(VP.UTILIDAD_TOTAL)                                 AS utilidad
    FROM VENDIDO_PRODUCTOS VP
    INNER JOIN FACTURAS  F ON VP.IDX_FACTURA  = F.ID_FACTURA
    INNER JOIN PRODUCTOS P ON VP.IDX_PRODUCTO = P.PRODUCT_ID
    WHERE F.FECHA_VENTA BETWEEN @fecha_inicio AND @fecha_fin
    GROUP BY P.PRODUCT_ID, P.CODIGO_BARRAS, P.PRODUCTO, P.COSTO_X_UNIDAD
    ORDER BY SUM(VP.QUANTITY) DESC;
END
GO

-- ------------------------------------------------------------
-- 4.7  SP_DIAN_OBTENER_XML
--      Devuelve el XML firmado y metadatos para el ZIP SOAP.
--      Fuente: sp_dian_fase3.sql
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_DIAN_OBTENER_XML]
    @id_factura NUMERIC(18,0)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        F.XML_DIAN,
        ISNULL(F.ESTADO_DIAN, 'PENDIENTE')                              AS estado_dian,
        F.TRACK_ID_DIAN,
        ISNULL(RD.PREFIJO, '') + CAST(F.NUMERO_FACTURA_DIAN AS VARCHAR(20)) AS zip_key,
        ISNULL(CF.AMBIENTE_DIAN, 2)                                     AS ambiente_dian
    FROM FACTURAS F
    CROSS JOIN CONFIGURACIONES CF
    LEFT JOIN RESOLUCIONES_DIAN RD
           ON RD.ACTIVA = 1
          AND RD.TIPO   = 'FC'
          AND CAST(F.FECHA_VENTA AS DATE)
              BETWEEN RD.FECHA_INICIO_VIGENCIA AND RD.FECHA_FIN_VIGENCIA
    WHERE F.ID_FACTURA = @id_factura
      AND F.XML_DIAN   IS NOT NULL;
END
GO

-- ------------------------------------------------------------
-- 4.8  SP_DIAN_GUARDAR_TRACK
--      Persiste el XmlDocumentKey devuelto por SendBillAsync.
--      Fuente: sp_dian_fase3.sql
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_DIAN_GUARDAR_TRACK]
    @id_factura NUMERIC(18,0),
    @track_id   VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE FACTURAS
    SET TRACK_ID_DIAN = @track_id
    WHERE ID_FACTURA = @id_factura;
END
GO

-- ------------------------------------------------------------
-- 4.9  SP_DIAN_EMPRESA_CONSULTAR
--      Fuente: sp_dian_config.sql
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_DIAN_EMPRESA_CONSULTAR]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1
        ISNULL(NOMBRE_COMERCIAL,                      '') AS NOMBRE_COMERCIAL,
        ISNULL(DIGITO_VERIFICACION,                   '') AS DIGITO_VERIFICACION,
        ISNULL(MUNICIPIO_DIAN,                        '') AS MUNICIPIO_DIAN,
        ISNULL(DEPARTAMENTO_DIAN,                     '') AS DEPARTAMENTO_DIAN,
        ISNULL(CODIGO_POSTAL,                         '') AS CODIGO_POSTAL,
        ISNULL(IDX_TIPO_DOCUMENTO_EMPRESA,             0) AS IDX_TIPO_DOCUMENTO_EMPRESA,
        ISNULL(IDX_REGIMEN_TRIBUTARIO_EMPRESA,         0) AS IDX_REGIMEN_TRIBUTARIO_EMPRESA,
        ISNULL(IDX_RESPONSABILIDAD_FISCAL_EMPRESA,     0) AS IDX_RESPONSABILIDAD_FISCAL_EMPRESA,
        ISNULL(AMBIENTE_DIAN,                          2) AS AMBIENTE_DIAN
    FROM CONFIGURACIONES;
END
GO

-- ------------------------------------------------------------
-- 4.10  SP_DIAN_EMPRESA_ACTUALIZAR
--       Fuente: sp_dian_config.sql
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_DIAN_EMPRESA_ACTUALIZAR]
    @nombre_comercial                   VARCHAR(200) = NULL,
    @digito_verificacion                VARCHAR(2)   = NULL,
    @municipio_dian                     VARCHAR(10)  = NULL,
    @departamento_dian                  VARCHAR(10)  = NULL,
    @codigo_postal                      VARCHAR(10)  = NULL,
    @idx_tipo_documento_empresa         INT          = NULL,
    @idx_regimen_tributario_empresa     INT          = NULL,
    @idx_responsabilidad_fiscal_empresa INT          = NULL,
    @ambiente_dian                      INT          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE CONFIGURACIONES SET
        NOMBRE_COMERCIAL                   = ISNULL(@nombre_comercial,                   NOMBRE_COMERCIAL),
        DIGITO_VERIFICACION                = ISNULL(@digito_verificacion,                DIGITO_VERIFICACION),
        MUNICIPIO_DIAN                     = ISNULL(@municipio_dian,                     MUNICIPIO_DIAN),
        DEPARTAMENTO_DIAN                  = ISNULL(@departamento_dian,                  DEPARTAMENTO_DIAN),
        CODIGO_POSTAL                      = ISNULL(@codigo_postal,                      CODIGO_POSTAL),
        IDX_TIPO_DOCUMENTO_EMPRESA         = ISNULL(@idx_tipo_documento_empresa,         IDX_TIPO_DOCUMENTO_EMPRESA),
        IDX_REGIMEN_TRIBUTARIO_EMPRESA     = ISNULL(@idx_regimen_tributario_empresa,     IDX_REGIMEN_TRIBUTARIO_EMPRESA),
        IDX_RESPONSABILIDAD_FISCAL_EMPRESA = ISNULL(@idx_responsabilidad_fiscal_empresa, IDX_RESPONSABILIDAD_FISCAL_EMPRESA),
        AMBIENTE_DIAN                      = ISNULL(@ambiente_dian,                      AMBIENTE_DIAN);
END
GO

-- ------------------------------------------------------------
-- 4.11  SP_DIAN_RESOLUCIONES_LISTAR
--       Fuente: sp_dian_config.sql
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_DIAN_RESOLUCIONES_LISTAR]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        ID_RESOLUCION,
        NUMERO_RESOLUCION,
        FECHA_RESOLUCION,
        FECHA_INICIO_VIGENCIA,
        FECHA_FIN_VIGENCIA,
        ISNULL(PREFIJO, '')                          AS PREFIJO,
        RANGO_INICIO,
        RANGO_FIN,
        NUMERO_ACTUAL,
        CLAVE_TECNICA,
        TIPO,
        ACTIVA,
        DATEDIFF(DAY, GETDATE(), FECHA_FIN_VIGENCIA) AS DIAS_VIGENCIA,
        RANGO_FIN - NUMERO_ACTUAL                    AS NUMEROS_DISPONIBLES
    FROM RESOLUCIONES_DIAN
    ORDER BY ACTIVA DESC, FECHA_FIN_VIGENCIA DESC;
END
GO

-- ------------------------------------------------------------
-- 4.12  SP_DIAN_RESOLUCION_CREAR
--       Fuente: sp_dian_config.sql
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_DIAN_RESOLUCION_CREAR]
    @numero_resolucion VARCHAR(20),
    @fecha_resolucion  DATE,
    @fecha_inicio      DATE,
    @fecha_fin         DATE,
    @prefijo           VARCHAR(10) = NULL,
    @rango_inicio      NUMERIC,
    @rango_fin         NUMERIC,
    @clave_tecnica     VARCHAR(200),
    @tipo              VARCHAR(2)  = 'FC'
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO RESOLUCIONES_DIAN (
        NUMERO_RESOLUCION, FECHA_RESOLUCION,
        FECHA_INICIO_VIGENCIA, FECHA_FIN_VIGENCIA,
        PREFIJO, RANGO_INICIO, RANGO_FIN,
        NUMERO_ACTUAL, CLAVE_TECNICA, TIPO, ACTIVA
    ) VALUES (
        @numero_resolucion, @fecha_resolucion,
        @fecha_inicio, @fecha_fin,
        @prefijo, @rango_inicio, @rango_fin,
        @rango_inicio - 1, @clave_tecnica, @tipo, 0
    );
    SELECT SCOPE_IDENTITY() AS ID_RESOLUCION;
END
GO

-- ------------------------------------------------------------
-- 4.13  SP_DIAN_RESOLUCION_ACTIVAR
--       Fuente: sp_dian_config.sql
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_DIAN_RESOLUCION_ACTIVAR]
    @id_resolucion NUMERIC,
    @tipo          VARCHAR(2) = 'FC'
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE RESOLUCIONES_DIAN SET ACTIVA = 0 WHERE TIPO = @tipo;
    UPDATE RESOLUCIONES_DIAN SET ACTIVA = 1 WHERE ID_RESOLUCION = @id_resolucion;
END
GO

-- ------------------------------------------------------------
-- 4.14  SP_DIAN_TIPOS_IVA
--       Fuente: sp_dian_config.sql
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_DIAN_TIPOS_IVA]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        ID_TIPO_IVA,
        DESCRIPCION + ' (' + CAST(PORCENTAJE AS VARCHAR) + '%)' AS TIPO_IVA,
        PORCENTAJE,
        CODIGO_TRIBUTO,
        NOMBRE_TRIBUTO
    FROM TIPOS_IVA
    ORDER BY ID_TIPO_IVA;
END
GO

-- ------------------------------------------------------------
-- 4.15  SP_DIAN_PRODUCTO_CAMPOS
--       Fuente: sp_dian_config.sql
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_DIAN_PRODUCTO_CAMPOS]
    @id_producto NUMERIC
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        ISNULL(CODIGO_UNSPSC, '') AS CODIGO_UNSPSC,
        IDX_TIPO_IVA
    FROM PRODUCTOS
    WHERE PRODUCT_ID = @id_producto;
END
GO

-- ------------------------------------------------------------
-- 4.16  SP_DIAN_ACTUALIZAR_PRODUCTO
--       Fuente: sp_dian_config.sql
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_DIAN_ACTUALIZAR_PRODUCTO]
    @id_producto   NUMERIC,
    @codigo_unspsc VARCHAR(20) = NULL,
    @idx_tipo_iva  INT         = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE PRODUCTOS SET
        CODIGO_UNSPSC = ISNULL(@codigo_unspsc, CODIGO_UNSPSC),
        IDX_TIPO_IVA  = ISNULL(@idx_tipo_iva,  IDX_TIPO_IVA)
    WHERE PRODUCT_ID = @id_producto;
END
GO

-- ------------------------------------------------------------
-- 4.17  SP_DIAN_CLIENTE_CAMPOS
--       Fuente: sp_dian_config.sql
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_DIAN_CLIENTE_CAMPOS]
    @id_cliente NUMERIC
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        ISNULL(MUNICIPIO_DIAN,      '') AS MUNICIPIO_DIAN,
        ISNULL(CODIGO_POSTAL,       '') AS CODIGO_POSTAL,
        ISNULL(DIGITO_VERIFICACION, '') AS DIGITO_VERIFICACION
    FROM CLIENTES
    WHERE CLIENTE_ID = @id_cliente;
END
GO

-- ------------------------------------------------------------
-- 4.18  SP_DIAN_ACTUALIZAR_CLIENTE
--       Fuente: sp_dian_config.sql
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_DIAN_ACTUALIZAR_CLIENTE]
    @id_cliente          NUMERIC,
    @municipio_dian      VARCHAR(10) = NULL,
    @codigo_postal       VARCHAR(10) = NULL,
    @digito_verificacion VARCHAR(2)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE CLIENTES SET
        MUNICIPIO_DIAN      = ISNULL(@municipio_dian,      MUNICIPIO_DIAN),
        CODIGO_POSTAL       = ISNULL(@codigo_postal,       CODIGO_POSTAL),
        DIGITO_VERIFICACION = ISNULL(@digito_verificacion, DIGITO_VERIFICACION)
    WHERE CLIENTE_ID = @id_cliente;
END
GO

-- ------------------------------------------------------------
-- 4.19  SP_DIAN_PAGO_CAMPOS
--       Fuente: sp_dian_config.sql
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_DIAN_PAGO_CAMPOS]
    @id_forma_pago NUMERIC
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ISNULL(CODIGO_MEDIO_PAGO_DIAN, '') AS CODIGO_MEDIO_PAGO_DIAN
    FROM FORMAS_PAGO
    WHERE ID_FORMA_PAGO = @id_forma_pago;
END
GO

-- ------------------------------------------------------------
-- 4.20  SP_DIAN_ACTUALIZAR_PAGO
--       Fuente: sp_dian_config.sql
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_DIAN_ACTUALIZAR_PAGO]
    @id_forma_pago          NUMERIC,
    @codigo_medio_pago_dian VARCHAR(3)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE FORMAS_PAGO
    SET CODIGO_MEDIO_PAGO_DIAN = @codigo_medio_pago_dian
    WHERE ID_FORMA_PAGO = @id_forma_pago;
END
GO

-- ------------------------------------------------------------
-- 4.21  SP_DIAN_REPORTE_ESTADOS
--       Facturas con su estado de procesamiento DIAN.
--       Fuente: sp_dian_reporte.sql
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_DIAN_REPORTE_ESTADOS]
    @estado_dian  VARCHAR(20) = NULL,  -- NULL = todos los estados
    @fecha_inicio DATE        = NULL,
    @fecha_fin    DATE        = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        F.ID_FACTURA,
        ISNULL(F.NUMERO_FACTURA_DIAN, '0')                   AS NUMERO_FACTURA_DIAN,
        F.FECHA_VENTA,
        CONCAT(CL.NOMBRES, ' ', CL.APELLIDOS)                AS CLIENTE_NOMBRE,
        F.ESTADO_DIAN,
        ISNULL(F.NOTAS_DIAN,   '')                           AS NOTAS_DIAN,
        ISNULL(F.CUFE_FACTURA, '')                           AS CUFE_FACTURA,
        ISNULL(F.QR_DIAN,      '')                           AS QR_DIAN,
        F.COSTO_TOTAL
    FROM FACTURAS F
    INNER JOIN CLIENTES CL ON F.IDX_CLIENTE = CL.CLIENTE_ID
    WHERE F.ESTADO_DIAN IS NOT NULL
      AND ISNULL(F.ANULADO, 0) = 0
      AND (@estado_dian  IS NULL OR F.ESTADO_DIAN              = @estado_dian)
      AND (@fecha_inicio IS NULL OR CAST(F.FECHA_VENTA AS DATE) >= @fecha_inicio)
      AND (@fecha_fin    IS NULL OR CAST(F.FECHA_VENTA AS DATE) <= @fecha_fin)
    ORDER BY
        CASE F.ESTADO_DIAN
            WHEN 'RECHAZADA'    THEN 1
            WHEN 'CONTINGENCIA' THEN 2
            WHEN 'PENDIENTE'    THEN 3
            WHEN 'VALIDADA'     THEN 4
            ELSE 5
        END,
        F.FECHA_VENTA DESC;
END
GO

-- ------------------------------------------------------------
-- 4.22  SP_CARGADO_CONFIGURACION_GENERAL
--       Fuente: sp_iva_general.sql
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_CARGADO_CONFIGURACION_GENERAL]
AS
BEGIN
    SELECT
        ID_CONFIGURACION,
        NOMBRE_LEGAL_ESTABLECIMIENTO,
        NIT_EMPRESA,
        EMAIL_EMPRESA,
        DIRECCION,
        TELEFONO,
        PREFIJO_PAIS,
        ENVIO_WHATSAPP,
        ENVIO_CORREOS,
        API_WHATSAPP,
        VERSION_WHATSAPP,
        TOKEN_PERMANENTE_WHATSAPP,
        ID_TELEFONO_WHATSAPP,
        PORCENTAJE_GANANCIA,
        BIT_VALOR_PRODUCTO_PONDERADO AS BIT_PONDERADO,
        PORCENTAJE_IVA,
        BIT_IVA_INCLUIDO
    FROM CONFIGURACIONES;
END
GO

-- ------------------------------------------------------------
-- 4.23  SP_GUARDADO_CONFIGURACION_GENERAL
--       Fuente: sp_iva_general.sql
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_GUARDADO_CONFIGURACION_GENERAL]
    @id_configuracion          NUMERIC(18,0)  = NULL,
    @nombre_legal              VARCHAR(1000)  = NULL,
    @nit_empresa               VARCHAR(100)   = NULL,
    @email_empresa             VARCHAR(100)   = NULL,
    @direccion                 VARCHAR(100)   = NULL,
    @telefono                  VARCHAR(100)   = NULL,
    @prefijo_pais              VARCHAR(100)   = NULL,
    @envio_whatsapp            BIT            = NULL,
    @envio_correos             BIT            = NULL,
    @api_whatsapp              VARCHAR(100)   = NULL,
    @token_permanente_whatsapp VARCHAR(1000)  = NULL,
    @id_telefono_whatsapp      VARCHAR(100)   = NULL,
    @version_whatsapp          VARCHAR(100)   = NULL,
    @porcentaje_ganancia       NUMERIC(10,2)  = 0.00,
    @ponderado                 BIT            = 0,
    @porcentaje_iva            NUMERIC(18,2)  = NULL,
    @bit_iva_incluido          BIT            = NULL
AS
BEGIN
    IF (@id_configuracion IS NULL)
    BEGIN
        INSERT INTO CONFIGURACIONES (
            NOMBRE_LEGAL_ESTABLECIMIENTO, NIT_EMPRESA, DIRECCION, EMAIL_EMPRESA,
            TELEFONO, PREFIJO_PAIS, ENVIO_WHATSAPP, ENVIO_CORREOS,
            API_WHATSAPP, TOKEN_PERMANENTE_WHATSAPP, VERSION_WHATSAPP,
            ID_TELEFONO_WHATSAPP, PORCENTAJE_GANANCIA, BIT_VALOR_PRODUCTO_PONDERADO,
            PORCENTAJE_IVA, BIT_IVA_INCLUIDO
        )
        VALUES (
            @nombre_legal, @nit_empresa, @direccion, @email_empresa,
            @telefono, @prefijo_pais, @envio_whatsapp, @envio_correos,
            @api_whatsapp, @token_permanente_whatsapp, @version_whatsapp,
            @id_telefono_whatsapp, @porcentaje_ganancia, @ponderado,
            @porcentaje_iva, ISNULL(@bit_iva_incluido, 1)
        );
        SELECT 'GUARDADO' AS RESPUESTA;
    END
    ELSE
    BEGIN
        UPDATE CONFIGURACIONES SET
            NOMBRE_LEGAL_ESTABLECIMIENTO = @nombre_legal,
            NIT_EMPRESA                  = @nit_empresa,
            DIRECCION                    = @direccion,
            EMAIL_EMPRESA                = @email_empresa,
            TELEFONO                     = @telefono,
            PREFIJO_PAIS                 = @prefijo_pais,
            ENVIO_WHATSAPP               = @envio_whatsapp,
            ENVIO_CORREOS                = @envio_correos,
            API_WHATSAPP                 = @api_whatsapp,
            TOKEN_PERMANENTE_WHATSAPP    = @token_permanente_whatsapp,
            VERSION_WHATSAPP             = @version_whatsapp,
            ID_TELEFONO_WHATSAPP         = @id_telefono_whatsapp,
            PORCENTAJE_GANANCIA          = @porcentaje_ganancia,
            BIT_VALOR_PRODUCTO_PONDERADO = @ponderado,
            PORCENTAJE_IVA               = ISNULL(@porcentaje_iva,    PORCENTAJE_IVA),
            BIT_IVA_INCLUIDO             = ISNULL(@bit_iva_incluido,  BIT_IVA_INCLUIDO)
        WHERE ID_CONFIGURACION = @id_configuracion;
        SELECT 'ACTUALIZADO' AS RESPUESTA;
    END
END
GO

-- ------------------------------------------------------------
-- 4.24  SP_ACCIONES_PRODUCTOS
--       Fuente: sp_iva_general.sql
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SP_ACCIONES_PRODUCTOS]
    @accion               VARCHAR(30),
    @product_id           INT            = NULL,
    @idx_categoria        INT            = NULL,
    @producto             VARCHAR(100)   = NULL,
    @costo_x_unidad       NUMERIC(18,2)  = NULL,
    @cantidad             NUMERIC(18,2)  = NULL,
    @idx_tipo_medida      NUMERIC(18,0)  = NULL,
    @idx_medida           NUMERIC(18,0)  = NULL,
    @estado               BIT            = NULL,
    @idx_proveedor        DECIMAL        = NULL,
    @codigo_barras        VARCHAR(MAX)   = NULL,
    @idx_tipo_gramaje     NUMERIC(18,2)  = NULL,
    @gramaje              NUMERIC(18,2)  = NULL,
    @GRAMAJE_DEL_PRODUCTO NUMERIC(18,2)  = NULL,
    @porcentaje_iva       NUMERIC(18,2)  = NULL,
    @tipo_impuesto        VARCHAR(20)    = NULL
AS
BEGIN
    IF @accion = 'crear'
    BEGIN
        DECLARE @ponderado           BIT           = (SELECT TOP 1 ISNULL(BIT_VALOR_PRODUCTO_PONDERADO, 0) FROM CONFIGURACIONES);
        DECLARE @porcentaje_ganancia NUMERIC(10,2) = (SELECT TOP 1 ISNULL(PORCENTAJE_GANANCIA, 0)         FROM CONFIGURACIONES);

        IF (@ponderado = 1)
        BEGIN
            INSERT INTO PRODUCTOS (
                IDX_CATEGORIA, PRODUCTO, COSTO_X_UNIDAD, QUANTITY, ESTADOS,
                IDX_TIPO_MEDIDA, IDX_MEDIDA, IDX_PROVEEDOR, CODIGO_BARRAS,
                IDX_TIPO_GRAMAJE, GRAMAJE, GRAMAJE_DEL_PRODUCTO,
                PORCENTAJE_IVA, TIPO_IMPUESTO
            )
            VALUES (
                @idx_categoria, @producto, @costo_x_unidad, @cantidad, @estado,
                @idx_tipo_medida, @idx_medida, @idx_proveedor, @codigo_barras,
                @idx_tipo_gramaje, @gramaje, @GRAMAJE_DEL_PRODUCTO,
                @porcentaje_iva, @tipo_impuesto
            );
        END
        ELSE
        BEGIN
            INSERT INTO PRODUCTOS (
                IDX_CATEGORIA, PRODUCTO, COSTO_X_UNIDAD, QUANTITY, ESTADOS,
                IDX_TIPO_MEDIDA, IDX_MEDIDA, IDX_PROVEEDOR, CODIGO_BARRAS,
                IDX_TIPO_GRAMAJE, GRAMAJE, GRAMAJE_DEL_PRODUCTO,
                PORCENTAJE_IVA, TIPO_IMPUESTO
            )
            VALUES (
                @idx_categoria, @producto,
                (@costo_x_unidad * @porcentaje_ganancia) + @costo_x_unidad,
                @cantidad, @estado,
                @idx_tipo_medida, @idx_medida, @idx_proveedor, @codigo_barras,
                @idx_tipo_medida, @gramaje, @GRAMAJE_DEL_PRODUCTO,
                @porcentaje_iva, @tipo_impuesto
            );
        END
        SELECT 'Insertado' AS Respuesta;
    END
    ELSE IF @accion = 'existeCodigo'
    BEGIN
        SELECT CASE WHEN COUNT(PRODUCT_ID) > 0 THEN 'Existe' ELSE '!Existe' END AS Respuesta
        FROM PRODUCTOS WHERE CODIGO_BARRAS = @codigo_barras;
    END
    ELSE IF @accion = 'actualizar'
    BEGIN
        UPDATE PRODUCTOS SET
            IDX_CATEGORIA        = @idx_categoria,
            PRODUCTO             = @producto,
            COSTO_X_UNIDAD       = @costo_x_unidad,
            QUANTITY             = @cantidad,
            ESTADOS              = @estado,
            IDX_TIPO_MEDIDA      = @idx_tipo_medida,
            IDX_MEDIDA           = @idx_medida,
            IDX_PROVEEDOR        = @idx_proveedor,
            CODIGO_BARRAS        = @codigo_barras,
            IDX_TIPO_GRAMAJE     = @idx_tipo_gramaje,
            GRAMAJE              = @gramaje,
            GRAMAJE_DEL_PRODUCTO = @GRAMAJE_DEL_PRODUCTO,
            PORCENTAJE_IVA       = @porcentaje_iva,
            TIPO_IMPUESTO        = @tipo_impuesto
        WHERE PRODUCT_ID = @product_id;
        SELECT 'Actualizado' AS Respuesta;
    END
    ELSE IF @accion = 'seleccionar'
    BEGIN
        SELECT
            P.PRODUCT_ID          AS productId,
            P.IDX_CATEGORIA       AS idxCategoria,
            P.PRODUCTO            AS producto1,
            P.COSTO_X_UNIDAD      AS costoXUnidad,
            P.QUANTITY            AS quantity,
            P.ESTADOS             AS estados,
            P.IDX_MEDIDA,
            P.IDX_TIPO_MEDIDA,
            CT.CATEGORIA_ID,
            CT.CATEGORIA,
            CT.ESTADOS            AS estadoCategoria,
            P.IDX_PROVEEDOR       AS proveedor,
            P.CODIGO_BARRAS,
            P.IDX_TIPO_GRAMAJE,
            P.GRAMAJE,
            P.GRAMAJE_DEL_PRODUCTO,
            MP.EQUIVALENCIA_MEDIDA AS TIPO_GRAMAJE,
            P.PORCENTAJE_IVA,
            P.TIPO_IMPUESTO
        FROM PRODUCTOS P
        INNER JOIN CATEGORIAS     CT ON P.IDX_CATEGORIA    = CT.CATEGORIA_ID
        LEFT  JOIN MEDIDAS_PESADO MP ON P.IDX_TIPO_GRAMAJE = MP.ID_MEDIDAS_PESADO;

        SELECT * FROM TIPOS_MEDIDA;
        SELECT * FROM MEDIDAS_PESADO;
    END
END
GO


-- ============================================================
PRINT '====================================================';
PRINT 'DIAN_UNIFICADO.sql ejecutado correctamente.';
PRINT 'Tablas:  RESOLUCIONES_DIAN, TIPOS_IVA';
PRINT 'Columnas nuevas en: FACTURAS, CONFIGURACIONES,';
PRINT '                    PRODUCTOS, CLIENTES, FORMAS_PAGO';
PRINT 'SPs creados/actualizados: 24';
PRINT '====================================================';
GO
