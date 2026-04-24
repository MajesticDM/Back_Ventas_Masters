-- ============================================================
-- DIAN Report: returns invoices with their DIAN processing state
-- Run after sp_dian_fase3.sql
-- ============================================================

CREATE OR ALTER PROCEDURE SP_DIAN_REPORTE_ESTADOS
    @estado_dian  VARCHAR(20) = NULL,   -- NULL = all statuses
    @fecha_inicio DATE        = NULL,
    @fecha_fin    DATE        = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        f.ID_FACTURA,
        ISNULL(f.NUMERO_FACTURA_DIAN, '0')               AS NUMERO_FACTURA_DIAN,
        f.FECHA_VENTA,
        CONCAT(NOMBRES, ' ', APELLIDOS)            AS CLIENTE_NOMBRE,
        f.ESTADO_DIAN,
        ISNULL(f.NOTAS_DIAN,    '')                      AS NOTAS_DIAN,
        ISNULL(f.CUFE_FACTURA,  '')                      AS CUFE_FACTURA,
        ISNULL(f.QR_DIAN,       '')                      AS QR_DIAN,
        f.COSTO_TOTAL
    FROM   FACTURAS f
    INNER  JOIN CLIENTES        c  ON f.IDX_CLIENTE              = c.CLIENTE_ID
    WHERE  f.ESTADO_DIAN IS NOT NULL
      AND  ISNULL(f.ANULADO, 0) = 0
      AND  (@estado_dian  IS NULL OR f.ESTADO_DIAN              = @estado_dian)
      AND  (@fecha_inicio IS NULL OR CAST(f.FECHA_VENTA AS DATE) >= @fecha_inicio)
      AND  (@fecha_fin    IS NULL OR CAST(f.FECHA_VENTA AS DATE) <= @fecha_fin)
    ORDER BY
        CASE f.ESTADO_DIAN
            WHEN 'RECHAZADA'    THEN 1
            WHEN 'CONTINGENCIA' THEN 2
            WHEN 'PENDIENTE'    THEN 3
            WHEN 'VALIDADA'     THEN 4
            ELSE 5
        END,
        f.FECHA_VENTA DESC;
END
GO
