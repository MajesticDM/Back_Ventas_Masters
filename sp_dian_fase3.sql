
-- ============================================================
-- DIAN FASE 3 — Transmisión + Respuesta
-- Fecha: 2026-04-19
-- Seguro re-ejecutar (IF NOT EXISTS / CREATE OR ALTER).
--
-- Orden de ejecución: después de sp_dian_fase1_fixes.sql
--
-- Contenido:
--  A. FACTURAS.TRACK_ID_DIAN  — clave de seguimiento devuelta
--                               por DIAN al enviar el documento
--  B. SP_DIAN_OBTENER_XML     — devuelve el XML firmado + metadata
--                               necesaria para la transmisión
--  C. SP_DIAN_GUARDAR_TRACK   — guarda el TrackId tras el envío
-- ============================================================


-- ============================================================
-- A.  FACTURAS — TrackId de seguimiento DIAN
-- ============================================================
IF COL_LENGTH('FACTURAS', 'TRACK_ID_DIAN') IS NULL
    ALTER TABLE FACTURAS ADD [TRACK_ID_DIAN] VARCHAR(100) NULL;
GO


-- ============================================================
-- B.  SP_DIAN_OBTENER_XML
--     Devuelve el XML firmado y los metadatos necesarios para
--     construir el ZIP y autenticar contra el servicio SOAP.
--     Solo retorna filas donde XML_DIAN no sea NULL.
-- ============================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SP_DIAN_OBTENER_XML]
    @id_factura NUMERIC(18,0)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        F.XML_DIAN,
        ISNULL(F.ESTADO_DIAN, 'PENDIENTE')                               AS estado_dian,
        F.TRACK_ID_DIAN,
        -- ZipKey: prefijo + número consecutivo DIAN (sin espacio, sin extensión)
        -- Ejemplo: 'SETT000001'
        ISNULL(RD.PREFIJO, '') + CAST(F.NUMERO_FACTURA_DIAN AS VARCHAR(20)) AS zip_key,
        ISNULL(CF.AMBIENTE_DIAN, 2)                                      AS ambiente_dian
    FROM FACTURAS F
    CROSS JOIN CONFIGURACIONES CF           -- fila única de configuración
    LEFT JOIN RESOLUCIONES_DIAN RD
           ON RD.ACTIVA = 1
          AND RD.TIPO   = 'FC'
          AND CAST(F.FECHA_VENTA AS DATE)
              BETWEEN RD.FECHA_INICIO_VIGENCIA AND RD.FECHA_FIN_VIGENCIA
    WHERE F.ID_FACTURA = @id_factura
      AND F.XML_DIAN   IS NOT NULL;
END
GO


-- ============================================================
-- C.  SP_DIAN_GUARDAR_TRACK
--     Persiste el XmlDocumentKey devuelto por SendBillAsync.
--     El estado permanece PENDIENTE durante el sondeo.
-- ============================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

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

PRINT 'DIAN Fase 3: TRACK_ID_DIAN agregado y SPs creados correctamente.';
GO
