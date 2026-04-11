USE [MOTO_MASTERS]
GO

-- ============================================================
-- SP_ULTIMO_ABONO_FACTURA
-- Retorna el ID del abono mas reciente para una factura
-- dada, usado inmediatamente despues de guardar el abono
-- para obtener el ID sin modificar SP_ABONOS_VENTAS.
--
-- Parametros:
--   @idx_factura NUMERIC : factura sobre la que se abono
--   @idx_usuario NUMERIC : usuario que registro el abono
-- ============================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SP_ULTIMO_ABONO_FACTURA]
    @idx_factura NUMERIC(18,0),
    @idx_usuario NUMERIC(18,0)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1
        ID_DETALLE AS id_detalle
    FROM DETALLE_ABONOS_VENTAS
    WHERE IDX_FACTURA = @idx_factura
      AND IDX_USUARIO = @idx_usuario
    ORDER BY FECHA_ABONO DESC, ID_DETALLE DESC;
END
GO



-- ============================================================
-- SP_DETALLE_FACTURA
-- Retorna el detalle completo de una factura para imprimir
-- el recibo en impresora POS.
--
-- Parametro:
--   @id_factura NUMERIC : PK de la factura
--
-- Resultado 1 — Cabecera de la factura
-- Resultado 2 — Lineas (productos y servicios vendidos)
-- ============================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SP_DETALLE_FACTURA]
    @id_factura NUMERIC(18, 0)
AS
BEGIN
    SET NOCOUNT ON;

    -- -------------------------------------------------------
    -- Resultado 1: Cabecera
    -- -------------------------------------------------------
    SELECT
        F.ID_FACTURA                                                AS id_factura,
        FORMAT(F.FECHA_VENTA, 'dd/MM/yyyy HH:mm')                  AS fecha_venta,
        CONCAT(CL.NOMBRES, ' ', CL.APELLIDOS)                      AS cliente,
        CL.NUMERO_TELEFONO                                          AS telefono_cliente,
        ISNULL(CL.IDENTIFICACION, 0)                               AS identificacion_cliente,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                      AS vendedor,
        FP.FORMA_PAGO                                               AS forma_pago,
        F.COSTO_TOTAL                                               AS total,
        F.VALOR_PAGADO                                              AS pagado,
        CASE WHEN F.IDX_FORMA_PAGO = 2 THEN F.COSTO_TOTAL - F.VALOR_PAGADO  ELSE 0 END AS pendiente,
        ISNULL(F.VALOR_IVA, 0)                                     AS valor_iva,
        ISNULL(F.CONSUMIDOR_FINAL, 0)                              AS consumidor_final,
        ISNULL(F.CUFE_FACTURA, '')                                  AS cufe_factura
    FROM FACTURAS F
    INNER JOIN CLIENTES         CL ON F.IDX_CLIENTE            = CL.CLIENTE_ID
    INNER JOIN USUARIOS         US ON F.IDX_USUARIO            = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES DP ON US.IDX_DATOS_PERSONALES  = DP.DATOS_PERSONALES_ID
    INNER JOIN FORMAS_PAGO      FP ON F.IDX_FORMA_PAGO         = FP.ID_FORMA_PAGO
    WHERE F.ID_FACTURA = @id_factura;

    -- -------------------------------------------------------
    -- Resultado 2: Lineas de productos vendidos
    -- -------------------------------------------------------
    SELECT
        P.CODIGO_BARRAS                                             AS codigo,
        P.PRODUCTO                                                  AS nombre,
        VP.QUANTITY                                                 AS cantidad,
        ISNULL(VP.GRAMAJE_VENDIDO, 0)                                AS gramaje_total,
        CASE
            WHEN ISNULL(VP.GRAMAJE_VENDIDO, 0) > 0 AND VP.QUANTITY > 0
            THEN VP.TOTAL_COST / VP.GRAMAJE_VENDIDO
            ELSE CASE WHEN VP.QUANTITY > 0
                 THEN VP.TOTAL_COST / VP.QUANTITY
                 ELSE 0 END
        END                                                         AS precio_unitario,
        VP.TOTAL_COST                                               AS total_linea,
        ISNULL(VP.UTILIDAD_TOTAL, 0)                               AS utilidad_total
    FROM VENDIDO_PRODUCTOS VP
    INNER JOIN PRODUCTOS P ON VP.IDX_PRODUCTO = P.PRODUCT_ID
    WHERE VP.IDX_FACTURA = @id_factura
    ORDER BY VP.ID_VENDIDO_PRODUCT;

END
GO

-- ============================================================
-- SP_DETALLE_ABONO_VENTA
-- Retorna el detalle de un abono recibido de un cliente
-- para imprimir el comprobante en impresora POS.
--
-- Parametro:
--   @id_detalle NUMERIC : PK del DETALLE_ABONOS_VENTAS
-- ============================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SP_DETALLE_ABONO_VENTA]
    @id_detalle NUMERIC(18, 0)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        DAV.ID_DETALLE                                              AS id_detalle,
        FORMAT(DAV.FECHA_ABONO, 'dd/MM/yyyy HH:mm')               AS fecha_abono,
        DAV.IDX_FACTURA                                             AS id_factura,
        CONCAT(CL.NOMBRES, ' ', CL.APELLIDOS)                      AS cliente,
        CL.NUMERO_TELEFONO                                          AS telefono_cliente,
        ISNULL(CL.IDENTIFICACION, '')                               AS identificacion_cliente,
        ISNULL(FP.FORMA_PAGO, 'N/A')                               AS forma_pago,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                      AS usuario,
        DAV.VALOR_ABONADO                                           AS valor_abonado,
        F.COSTO_TOTAL                                               AS total_factura,
        F.VALOR_PAGADO                                              AS pagado_total,
        F.COSTO_TOTAL - F.VALOR_PAGADO                             AS saldo_restante,
        ISNULL(DAV.COMENTARIO, '')                                  AS comentario
    FROM DETALLE_ABONOS_VENTAS DAV
    INNER JOIN CLIENTES         CL ON DAV.IDX_CLIENTE          = CL.CLIENTE_ID
    INNER JOIN FACTURAS         F  ON DAV.IDX_FACTURA          = F.ID_FACTURA
    INNER JOIN USUARIOS         US ON DAV.IDX_USUARIO          = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES DP ON US.IDX_DATOS_PERSONALES  = DP.DATOS_PERSONALES_ID
    LEFT  JOIN FORMAS_PAGO      FP ON DAV.IDX_FORMA_PAGO       = FP.ID_FORMA_PAGO
    WHERE DAV.ID_DETALLE = @id_detalle;

END
GO
