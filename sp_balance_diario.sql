USE [MOTO_MASTERS]
GO

-- ============================================================
-- SP_BALANCE_DIARIO_IMPRIMIBLE
-- Retorna el detalle completo de movimientos en un rango de
-- fechas libre para generar el balance diario imprimible.
--
-- Parametros:
--   @fecha_inicio DATETIME : inicio del rango
--   @fecha_fin    DATETIME : fin del rango
--
-- Resultado 1 — Ventas (Facturas) del rango
-- Resultado 2 — Compras del rango
-- Resultado 3 — Gastos (Movimientos de caja - egresos)
-- Resultado 4 — Abonos recibidos de clientes
-- Resultado 5 — Abonos pagados a proveedores
-- ============================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SP_BALANCE_DIARIO_IMPRIMIBLE]
    @fecha_inicio DATETIME,
    @fecha_fin    DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    -- -------------------------------------------------------
    -- Resultado 1: Ventas (Facturas) del rango
    -- -------------------------------------------------------
    SELECT
        F.ID_FACTURA                                                AS id_factura,
        FORMAT(F.FECHA_VENTA, 'dd/MM/yyyy HH:mm')                  AS fecha_venta,
        CONCAT(CL.NOMBRES, ' ', CL.APELLIDOS)                      AS cliente,
        FP.FORMA_PAGO                                               AS forma_pago,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                      AS vendedor,
        F.COSTO_TOTAL                                               AS total,
        F.VALOR_PAGADO                                              AS pagado,
        CASE WHEN F.IDX_FORMA_PAGO = 2 THEN F.COSTO_TOTAL - F.VALOR_PAGADO  ELSE 0 END AS pendiente,
        ISNULL(UP.utilidad_factura, 0)                             AS utilidad_total
    FROM FACTURAS F
    INNER JOIN CLIENTES         CL ON F.IDX_CLIENTE            = CL.CLIENTE_ID
    INNER JOIN USUARIOS         US ON F.IDX_USUARIO            = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES DP ON US.IDX_DATOS_PERSONALES  = DP.DATOS_PERSONALES_ID
    INNER JOIN FORMAS_PAGO      FP ON F.IDX_FORMA_PAGO         = FP.ID_FORMA_PAGO
    LEFT JOIN (
        SELECT IDX_FACTURA, SUM(UTILIDAD_TOTAL) AS utilidad_factura
        FROM VENDIDO_PRODUCTOS
        GROUP BY IDX_FACTURA
    ) UP ON F.ID_FACTURA = UP.IDX_FACTURA
    WHERE F.FECHA_VENTA BETWEEN @fecha_inicio AND @fecha_fin
    ORDER BY F.FECHA_VENTA;

    -- -------------------------------------------------------
    -- Resultado 2: Compras del rango
    -- -------------------------------------------------------
    SELECT
        C.ID_COMPRA                                                 AS id_compra,
        FORMAT(C.FECHA_COMPRA, 'dd/MM/yyyy HH:mm')                 AS fecha_compra,
        PV.RAZON_SOCIAL                                             AS proveedor,
        FP.FORMA_PAGO                                               AS forma_pago,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                      AS comprador,
        C.COSTO_TOTAL                                               AS total,
        C.VALOR_PAGADO                                              AS pagado,
        C.COSTO_TOTAL - C.VALOR_PAGADO                             AS pendiente
    FROM COMPRAS C
    INNER JOIN PROVEEDORES      PV ON C.IDX_PROVEEDOR            = PV.ID_PROVEEDOR
    INNER JOIN USUARIOS         US ON C.IDX_USUARIO_COMPRADOR    = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES DP ON US.IDX_DATOS_PERSONALES    = DP.DATOS_PERSONALES_ID
    INNER JOIN FORMAS_PAGO      FP ON C.IDX_FORMA_PAGO           = FP.ID_FORMA_PAGO
    WHERE C.FECHA_COMPRA BETWEEN @fecha_inicio AND @fecha_fin
    ORDER BY C.FECHA_COMPRA;

    -- -------------------------------------------------------
    -- Resultado 3: Gastos (Movimientos de caja - egresos IDX_TIPO_MOVIMIENTO = 2)
    -- -------------------------------------------------------
    SELECT
        FORMAT(MC.FECHA_MOVIMIENTO, 'dd/MM/yyyy HH:mm')            AS fecha,
        CASE
            WHEN MC.IDX_GASTO IS NULL OR MC.IDX_GASTO = 0
            THEN 'Sin categoria'
            ELSE G.NOMBRE
        END                                                          AS categoria_gasto,
        ISNULL(MC.DESCRIPCION, '')                                   AS descripcion,
        FP.FORMA_PAGO                                                AS forma_pago,
        MC.VALOR                                                     AS valor
    FROM MOVIMIENTOS_CAJA MC
    LEFT  JOIN GASTOS      G  ON MC.IDX_GASTO        = G.ID_GASTO
    INNER JOIN FORMAS_PAGO FP ON MC.IDX_DENOMINACION = FP.ID_FORMA_PAGO
    WHERE MC.IDX_TIPO_MOVIMIENTO = 2
      AND MC.FECHA_MOVIMIENTO BETWEEN @fecha_inicio AND @fecha_fin
    ORDER BY MC.FECHA_MOVIMIENTO;

    -- -------------------------------------------------------
    -- Resultado 4: Abonos recibidos de clientes (Abonos ventas)
    -- -------------------------------------------------------
    SELECT
        FORMAT(DAV.FECHA_ABONO, 'dd/MM/yyyy HH:mm')                AS fecha_abono,
        DAV.IDX_FACTURA                                             AS id_factura,
        CONCAT(CL.NOMBRES, ' ', CL.APELLIDOS)                      AS cliente,
        ISNULL(FP.FORMA_PAGO, 'N/A')                               AS forma_pago,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                      AS usuario,
        DAV.VALOR_ABONADO                                           AS valor_abonado
    FROM DETALLE_ABONOS_VENTAS DAV
    INNER JOIN CLIENTES         CL ON DAV.IDX_CLIENTE          = CL.CLIENTE_ID
    INNER JOIN USUARIOS         US ON DAV.IDX_USUARIO          = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES DP ON US.IDX_DATOS_PERSONALES  = DP.DATOS_PERSONALES_ID
    LEFT  JOIN FORMAS_PAGO      FP ON DAV.IDX_FORMA_PAGO       = FP.ID_FORMA_PAGO
    WHERE DAV.FECHA_ABONO BETWEEN @fecha_inicio AND @fecha_fin
    ORDER BY DAV.FECHA_ABONO;

    -- -------------------------------------------------------
    -- Resultado 5: Abonos pagados a proveedores (Abonos compras)
    -- -------------------------------------------------------
    SELECT
        FORMAT(DAC.FECHA_ABONO, 'dd/MM/yyyy HH:mm')                AS fecha_abono,
        DAC.IDX_COMPRA                                              AS id_compra,
        PV.RAZON_SOCIAL                                             AS proveedor,
        ISNULL(FP.FORMA_PAGO, 'N/A')                               AS forma_pago,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                      AS usuario,
        DAC.VALOR_ABONADO                                           AS valor_abonado
    FROM DETALLE_ABONOS_COMPRAS DAC
    INNER JOIN COMPRAS           C  ON DAC.IDX_COMPRA             = C.ID_COMPRA
    INNER JOIN PROVEEDORES       PV ON C.IDX_PROVEEDOR            = PV.ID_PROVEEDOR
    INNER JOIN USUARIOS          US ON DAC.IDX_USUARIO            = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES  DP ON US.IDX_DATOS_PERSONALES    = DP.DATOS_PERSONALES_ID
    LEFT  JOIN FORMAS_PAGO       FP ON DAC.IDX_FORMA_PAGO         = FP.ID_FORMA_PAGO
    WHERE DAC.FECHA_ABONO BETWEEN @fecha_inicio AND @fecha_fin
    ORDER BY DAC.FECHA_ABONO;

    -- -------------------------------------------------------
    -- Resultado 6: Resumen de productos vendidos en el rango
    -- -------------------------------------------------------
    SELECT
        P.CODIGO_BARRAS                                             AS codigo,
        P.PRODUCTO                                                  AS nombre,
        P.COSTO_X_UNIDAD                                            AS costo_actual,
        SUM(VP.QUANTITY)                                            AS cantidad_vendida,
        SUM(VP.TOTAL_COST)                                          AS ingresos,
        SUM(VP.UTILIDAD_TOTAL)                                      AS utilidad
    FROM VENDIDO_PRODUCTOS VP
    INNER JOIN FACTURAS  F ON VP.IDX_FACTURA  = F.ID_FACTURA
    INNER JOIN PRODUCTOS P ON VP.IDX_PRODUCTO = P.PRODUCT_ID
    WHERE F.FECHA_VENTA BETWEEN @fecha_inicio AND @fecha_fin
    GROUP BY P.PRODUCT_ID, P.CODIGO_BARRAS, P.PRODUCTO, P.COSTO_X_UNIDAD
    ORDER BY SUM(VP.QUANTITY) DESC;

END
GO
