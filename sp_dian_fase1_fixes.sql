
-- ============================================================
-- DIAN FASE 1 — Correcciones post-validación Anexo Técnico v1.9
-- Fecha: 2026-04-19
-- Seguro re-ejecutar (IF NOT EXISTS / CREATE OR ALTER).
--
-- Orden de ejecución: después de sp_dian_fase0.sql
--
-- Correcciones:
--  A. CLIENTES.DIGITO_VERIFICACION — dígito de verificación del
--     adquirente; necesario para CompanyID/@schemeID en UBL 2.1
--  B. FACTURAS.FECHA_VENCIMIENTO  — fecha límite de pago explícita;
--     si NULL se calcula +30d para crédito o = FECHA_VENTA para contado
--  C. SP_DIAN_DATOS_FACTURA (reescritura completa) — agrega:
--       adquirente_digito_verificacion
--       fecha_vencimiento_dian
--       prepago (PAGO_INICIAL)
--       maneja_credito (de FORMAS_PAGO)
--     Corrige: tipo_pago_dian usa FP.MANEJA_CREDITO en lugar de
--              hardcoded IDX_FORMA_PAGO = 2
-- ============================================================


-- ============================================================
-- A.  CLIENTES — dígito de verificación del adquirente
-- ============================================================
IF COL_LENGTH('CLIENTES', 'DIGITO_VERIFICACION') IS NULL
    ALTER TABLE CLIENTES ADD [DIGITO_VERIFICACION] VARCHAR(2) NULL;
GO


-- ============================================================
-- B.  FACTURAS — fecha de vencimiento explícita
-- ============================================================
IF COL_LENGTH('FACTURAS', 'FECHA_VENCIMIENTO') IS NULL
    ALTER TABLE FACTURAS ADD [FECHA_VENCIMIENTO] DATE NULL;
GO


-- ============================================================
-- C.  SP_DIAN_DATOS_FACTURA — reescritura completa
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
        FORMAT(F.FECHA_VENTA, 'yyyyMMdd')            AS fecha_dian,
        FORMAT(F.FECHA_VENTA, 'HH:mm:ss')
            + '-05:00'                               AS hora_dian,
        F.COSTO_TOTAL                                AS total,
        ISNULL(F.VALOR_IVA, 0)                       AS total_iva,
        F.COSTO_TOTAL - ISNULL(F.VALOR_IVA, 0)      AS subtotal,
        F.CONSUMIDOR_FINAL,
        -- Fecha de vencimiento para PaymentMeans/DueDate
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
        -- Prepago: pago inicial o saldo a favor aplicado
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
        ISNULL(RT_E.EQUIVALENCIA_REGIMEN_TRIBUTARIO, 'ZZ')       AS emisor_regimen,
        ISNULL(RF_E.EQUIVALENCIA_RESPONSABILIDAD,    'R-99-PN')  AS emisor_responsabilidad,
        ISNULL(TD_E.EQUIVALENCIA_TIPO,               '31')       AS emisor_tipo_documento,
        -- Adquirente (cliente)
        CONCAT(CL.NOMBRES, ' ', CL.APELLIDOS)        AS adquirente_nombre,
        CL.IDENTIFICACION                            AS adquirente_identificacion,
        -- schemeID en CompanyID UBL = dígito de verificación (0 para personas naturales)
        ISNULL(CL.DIGITO_VERIFICACION, '0')          AS adquirente_digito_verificacion,
        ISNULL(CL.CORREO_ELECTRONICO, '')            AS adquirente_email,
        CL.NUMERO_TELEFONO                           AS adquirente_telefono,
        ISNULL(CL.DIRECCION_FISCAL, 'No registrada') AS adquirente_direccion,
        ISNULL(CL.MUNICIPIO_DIAN,   '11001')         AS adquirente_municipio,
        ISNULL(CL.CODIGO_POSTAL,    '110111')        AS adquirente_codigo_postal,
        ISNULL(TD_C.EQUIVALENCIA_TIPO,    '13')      AS adquirente_tipo_documento,
        ISNULL(RT_C.EQUIVALENCIA_REGIMEN_TRIBUTARIO, 'ZZ')       AS adquirente_regimen,
        ISNULL(RF_C.EQUIVALENCIA_RESPONSABILIDAD,    'R-99-PN')  AS adquirente_responsabilidad,
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
        -- Usa FP.MANEJA_CREDITO en lugar de hardcoded IDX_FORMA_PAGO = 2
        CASE WHEN FP.MANEJA_CREDITO = 1 THEN 'Crédito' ELSE 'Contado' END AS tipo_pago_dian
    FROM FACTURAS F
    INNER JOIN CLIENTES          CL   ON F.IDX_CLIENTE    = CL.CLIENTE_ID
    CROSS JOIN CONFIGURACIONES   CF
    INNER JOIN FORMAS_PAGO       FP   ON F.IDX_FORMA_PAGO = FP.ID_FORMA_PAGO
    LEFT JOIN  RESOLUCIONES_DIAN RD
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
    INNER JOIN PRODUCTOS     P   ON VP.IDX_PRODUCTO = P.PRODUCT_ID
    LEFT  JOIN TIPOS_IVA     TI  ON P.IDX_TIPO_IVA  = TI.ID_TIPO_IVA
    LEFT  JOIN MEDIDAS_PESADO MP ON P.IDX_MEDIDA     = MP.ID_MEDIDAS_PESADO
    WHERE VP.IDX_FACTURA = @id_factura;

    -- ----------------------------------------------------------
    -- Resultado 2: Líneas de servicios
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


-- ============================================================
-- Guía de actualización de datos: dígito de verificación
-- Ejecutar una vez por cliente que tenga NIT (tipo doc = '31')
--
-- UPDATE CLIENTES SET DIGITO_VERIFICACION = '<dv>'
-- WHERE CLIENTE_ID = <id>;
--
-- Para personas naturales (CC, CE, etc.) dejar NULL → se usa '0'.
-- ============================================================
PRINT 'DIAN Fase 1 fixes aplicados correctamente.';
GO
