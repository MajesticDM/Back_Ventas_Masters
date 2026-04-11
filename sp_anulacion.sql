USE [MOTO_MASTERS]
GO

-- ============================================================
-- ANULACIÓN DE FACTURAS — cambios al esquema
-- Autor: Daniel  |  Fecha: 2026-04-11
--
-- Este archivo contiene TODOS los cambios necesarios para
-- soportar la anulación de facturas con integridad completa.
-- Es idempotente: ejecutar con CREATE OR ALTER es seguro.
--
-- ANTES DE CORRER: verificar que la columna ANULADO exista:
--   SELECT TOP 1 ANULADO FROM FACTURAS
-- Si no existe:
--   ALTER TABLE FACTURAS ADD ANULADO BIT NULL DEFAULT 0
--
-- Cambios incluidos:
--  1. SP_FACTURAS_ACCIONES   → agrega acción 'anularFactura'
--  2. SP_CARGADO_FACTURAS    → agrega @solo_anuladas + columna ANULADO
--  3. SP_BALANCE_PERIODOS    → excluye ANULADO = 1
--  4. SP_VENTAS_PRODUCTO_CODIGO → excluye ANULADO = 1
--  5. SP_TENDENCIA_PRODUCTO  → excluye ANULADO = 1
--  6. SP_LISTADO_PERIODOS    → excluye ANULADO = 1
--  7. SP_RADAR_STOCK         → excluye ANULADO = 1
--  8. SP_CARTERA_CLIENTES    → excluye ANULADO = 1 de facturas_pendientes
--  9. SP_MARGEN_REAL         → excluye VENDIDO_PRODUCTOS de facturas ANULADO = 1
-- 10. SP_ABONOS_VENTAS       → excluye ANULADO = 1 en operación FACTURAS
-- 11. SP_BALANCE_DIARIO_IMPRIMIBLE → excluye ANULADO = 1
-- 12. SP_UTILIDADES_ACCIONES → excluye ANULADO = 1 (cuadre de caja)
-- 13. SP_CARGAINICIAL_DASHBOARD → excluye ANULADO = 1 de totales
-- ============================================================

--CAMBIOS TABLAS

--ALTER TABLE FACTURAS ADD ANULADO BIT DEFAULT 0;


-- ============================================================
-- 1. SP_FACTURAS_ACCIONES — agrega acción 'anularFactura'
-- ============================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SP_FACTURAS_ACCIONES]
    @accion             varchar(100),
    @id_factura         numeric(18,0) = null,
    @idx_cliente        numeric(18,0) = null,
    @idx_usuario        numeric(18,0) = null,
    @costo_total        numeric(18,2) = null,
    @estado             bit           = null,
    @consumidor_final   bit           = null,
    @cufe_factura       varchar(1000) = null,
    @idx_producto       numeric(18,0) = null,
    @cantidad           numeric(18,2) = null,
    @forma_pago         numeric(18,0) = null,
    @forma_pago_inicial numeric(18,0) = 0,
    @pago_inicial       numeric(18,2) = null,
    @usa_saldo_favor    bit           = null,
    @gramaje_total      numeric(18,2) = null
AS
BEGIN
    declare @porcentaje_iva numeric(18,2) = ISNULL((SELECT TOP 1 PORCENTAJE_IVA FROM CONFIGURACIONES), 0)

    IF (@accion = 'crearFactura')
    BEGIN
        DECLARE @saldo_favor    DECIMAL(18, 2);
        DECLARE @saldo_negativo DECIMAL(18, 2);
        DECLARE @caja numeric(18,0) = (
            select top 1 ID_CAJA from CAJA
            where IDX_USUARIO = @idx_usuario and FECHA_CIERRE_CAJA IS NULL
        );

        SELECT
            @saldo_favor    = SALDO,
            @saldo_negativo = SALDO_NEGATIVO
        FROM CLIENTES
        WHERE CLIENTE_ID = @idx_cliente;

        IF (@usa_saldo_favor = 1)
        BEGIN
            DECLARE @disponible DECIMAL(18, 2) = +@saldo_favor;

            IF (@disponible >= @costo_total)
            BEGIN
                SET @pago_inicial   = @costo_total;
                SET @saldo_favor    = @disponible - @costo_total;
            END
            ELSE
            BEGIN
                SET @pago_inicial       = @disponible;
                SET @saldo_favor        = 0;
                SET @saldo_negativo     = @saldo_negativo + (@costo_total - @pago_inicial);
            END
        END
        ELSE
        BEGIN
            IF (@pago_inicial < @costo_total and @forma_pago = 2)
            BEGIN
                SET @saldo_negativo = @saldo_negativo + (@costo_total - @pago_inicial);
            END
        END

        UPDATE CLIENTES
        SET
            SALDO          = @saldo_favor,
            SALDO_NEGATIVO = @saldo_negativo
        WHERE CLIENTE_ID = @idx_cliente;

        DECLARE @NuevoID INT;

        INSERT INTO FACTURAS (
            IDX_CLIENTE, IDX_USUARIO, COSTO_TOTAL, CONSUMIDOR_FINAL,
            IDX_FORMA_PAGO, VALOR_PAGADO, PAGO_INICIAL, IDX_CAJA, IDX_FORMA_PAGO_INICIAL
        )
        VALUES (
            @idx_cliente, @idx_usuario, @costo_total, @consumidor_final,
            @forma_pago, @pago_inicial, @pago_inicial, @caja, @forma_pago_inicial
        );

        SET @NuevoID = SCOPE_IDENTITY();

        SELECT @NuevoID AS ID_INSERTADO;
    END

    ELSE IF (@accion = 'venderProducto')
    BEGIN
        declare @COSTO_UNITARIO_AL_VENDER  decimal(18,2) = (SELECT COSTO_X_UNIDAD FROM PRODUCTOS WHERE PRODUCT_ID = @idx_producto),
                @PRECIO_UNITARIO_VENTA     decimal(18,2) = @costo_total / @cantidad;
        declare @UTILIDAD_UNITARIA         decimal(18,2) = @PRECIO_UNITARIO_VENTA - @COSTO_UNITARIO_AL_VENDER;
        declare @UTILIDAD_TOTAL            decimal(18,2) = @UTILIDAD_UNITARIA * @cantidad;
        declare @gramaje_total_producto    numeric(18,2) = (SELECT GRAMAJE_DEL_PRODUCTO FROM PRODUCTOS WHERE PRODUCT_ID = @idx_producto)

        INSERT VENDIDO_PRODUCTOS (
            IDX_FACTURA, IDX_PRODUCTO, QUANTITY, TOTAL_COST, VALOR_IVA, SUB_TOTAL,
            COSTO_UNITARIO_AL_VENDER, PRECIO_UNITARIO_VENTA, UTILIDAD_UNITARIA, UTILIDAD_TOTAL, GRAMAJE_VENDIDO
        )
        VALUES (
            @id_factura, @idx_producto, @cantidad, @costo_total,
            (@costo_total * (@porcentaje_iva)),
            @costo_total - (@costo_total * (@porcentaje_iva)),
            @COSTO_UNITARIO_AL_VENDER, @PRECIO_UNITARIO_VENTA,
            @UTILIDAD_UNITARIA, @UTILIDAD_TOTAL, ISNULL(@gramaje_total, 0)
        )

        UPDATE PRODUCTOS
        SET
            QUANTITY             = (SELECT TOP 1 QUANTITY FROM PRODUCTOS WHERE PRODUCT_ID = @idx_producto) - @cantidad,
            GRAMAJE_DEL_PRODUCTO = (ISNULL(@gramaje_total_producto, 0) - ISNULL(@gramaje_total, 0))
        WHERE PRODUCT_ID = @idx_producto
    END

    ELSE IF (@accion = 'actualizarTotalIva')
    BEGIN
        UPDATE FACTURAS
        SET VALOR_IVA = (SELECT SUM(VALOR_IVA) FROM VENDIDO_PRODUCTOS WHERE IDX_FACTURA = @id_factura)
        WHERE ID_FACTURA = @id_factura
    END

    -- -------------------------------------------------------
    -- NUEVO: anulación completa de factura
    -- -------------------------------------------------------
    ELSE IF (@accion = 'anularFactura')
    BEGIN
        -- 1. Marcar la factura como anulada
        UPDATE FACTURAS SET ANULADO = 1 WHERE ID_FACTURA = @id_factura;

        -- 2. Restaurar stock de productos (invierte exactamente venderProducto)
        UPDATE P
        SET
            P.QUANTITY             = P.QUANTITY + VP.QUANTITY,
            P.GRAMAJE_DEL_PRODUCTO = P.GRAMAJE_DEL_PRODUCTO + ISNULL(VP.GRAMAJE_VENDIDO, 0)
        FROM PRODUCTOS P
        INNER JOIN VENDIDO_PRODUCTOS VP ON P.PRODUCT_ID = VP.IDX_PRODUCTO
        WHERE VP.IDX_FACTURA = @id_factura;

        -- 3. Revertir deuda del cliente (solo facturas a crédito IDX_FORMA_PAGO = 2)
        --    Si el pago fue a crédito, se había sumado al SALDO_NEGATIVO.
        --    Al anular, se resta el monto pendiente que aún no se había cobrado.
        --    El monto ya cobrado (PAGO_INICIAL) debe devolverse manualmente en caja.
        UPDATE CLIENTES
        SET SALDO_NEGATIVO = SALDO_NEGATIVO -
            ISNULL((
                SELECT CASE WHEN IDX_FORMA_PAGO = 2
                            THEN COSTO_TOTAL - ISNULL(VALOR_PAGADO, 0)
                            ELSE 0
                       END
                FROM FACTURAS
                WHERE ID_FACTURA = @id_factura
            ), 0)
        WHERE CLIENTE_ID = (SELECT IDX_CLIENTE FROM FACTURAS WHERE ID_FACTURA = @id_factura);
    END

END
GO


-- ============================================================
-- 2. SP_CARGADO_FACTURAS — agrega @solo_anuladas + columna ANULADO
-- ============================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SP_CARGADO_FACTURAS]
    @todas          bit,
    @fechaInicial   datetime = null,
    @fechaFinal     datetime = null,
    @cliente        decimal,
    @usuario        decimal,
    @solo_anuladas  bit = 0   -- 0 = ocultar anuladas (default) | 1 = solo anuladas
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        FC.ID_FACTURA, FC.COSTO_TOTAL, FC.IDX_CLIENTE, FC.IDX_USUARIO,
        FP.FORMA_PAGO AS forma_pago, FC.IDX_FORMA_PAGO AS medio,
        FORMAT(FC.FECHA_VENTA, 'dd/MM/yyyy hh:mm tt') AS FECHA_VENTA,
        CONCAT(CL.NOMBRES, ' ', CL.APELLIDOS)           AS CLIENTE_NOMBRE,
        CL.NUMERO_TELEFONO                               AS TELEFONO_CLIENTE,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)            AS USUARIO_NOMBRE,
        DP.NUMERO_TELEFONO                               AS TELEFONO_USUARIO,
        FC.CONSUMIDOR_FINAL, FC.VALOR_IVA,
        FC.VALOR_PAGADO AS pagado,
        FC.ANULADO                                       -- ← nuevo campo
    INTO #CLIENTES
    FROM FACTURAS FC
    INNER JOIN CLIENTES         CL ON FC.IDX_CLIENTE           = CL.CLIENTE_ID
    INNER JOIN USUARIOS         US ON FC.IDX_USUARIO            = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES DP ON US.IDX_DATOS_PERSONALES   = DP.DATOS_PERSONALES_ID
    INNER JOIN FORMAS_PAGO      FP ON FC.IDX_FORMA_PAGO         = FP.ID_FORMA_PAGO
    WHERE
        (
            (FC.FECHA_VENTA >= ISNULL(@fechaInicial, FC.FECHA_VENTA)
             AND FC.FECHA_VENTA <= ISNULL(@fechaFinal, FC.FECHA_VENTA))
            OR @todas = 1
        )
        AND (FC.IDX_USUARIO = @usuario OR @usuario = 0)
        AND (FC.IDX_CLIENTE = @cliente OR @cliente = 0)
        -- ← nuevo filtro por estado de anulación
        AND (
            (@solo_anuladas = 0 AND (FC.ANULADO IS NULL OR FC.ANULADO <> 1))
            OR
            (@solo_anuladas = 1 AND FC.ANULADO = 1)
        );

    -- Resultado 1: cabeceras de facturas
    SELECT * FROM #CLIENTES;

    -- Resultado 2: productos vendidos
    SELECT
        VP.IDX_FACTURA, VP.QUANTITY, VP.TOTAL_COST,
        VP.COSTO_UNITARIO_AL_VENDER AS valor_vendido,
        P.PRODUCTO, P.COSTO_X_UNIDAD, VP.SUB_TOTAL, VP.VALOR_IVA,
        MP.EQUIVALENCIA_MEDIDA,
        CASE MP.IDX_TIPO_MEDIDA
            WHEN 1 THEN ''
            ELSE CASE VP.QUANTITY WHEN 1 THEN 'unidad' ELSE 'unidades' END
        END AS EQUIVALENCIA,
        GRAMAJE_VENDIDO
    FROM VENDIDO_PRODUCTOS VP
    INNER JOIN PRODUCTOS     P  ON VP.IDX_PRODUCTO = P.PRODUCT_ID
    LEFT  JOIN MEDIDAS_PESADO MP ON P.IDX_MEDIDA   = MP.ID_MEDIDAS_PESADO
    WHERE VP.IDX_FACTURA IN (SELECT ID_FACTURA FROM #CLIENTES);

    -- Resultado 3: servicios vendidos
    SELECT SD.*, S.COSTO_REGULAR, S.SERVICIO
    FROM SERVICIOS_DADOS SD
    INNER JOIN SERVICIOS S ON SD.IDX_SERVICIO = S.SERVICIO_ID
    WHERE SD.IDX_FACTURA IN (SELECT ID_FACTURA FROM #CLIENTES);

    DROP TABLE #CLIENTES;
END
GO


-- ============================================================
-- 3. SP_BALANCE_PERIODOS — excluye facturas ANULADO = 1
-- ============================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SP_BALANCE_PERIODOS]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @hoy           DATE = CONVERT(DATE, GETDATE());
    DECLARE @inicio_semana DATE = DATEADD(WEEK, DATEDIFF(WEEK, 0, GETDATE()), 0);
    DECLARE @fin_semana    DATE = DATEADD(DAY, 6, @inicio_semana);
    DECLARE @inicio_mes    DATE = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
    DECLARE @fin_mes       DATE = EOMONTH(GETDATE());

    ;WITH cte_ventas AS (
        SELECT
            F.ID_FACTURA,
            F.COSTO_TOTAL,
            F.IDX_CLIENTE,
            CONVERT(DATE, F.FECHA_VENTA) AS fecha,
            ISNULL(VP.utilidad, 0)       AS utilidad
        FROM FACTURAS F
        LEFT JOIN (
            SELECT IDX_FACTURA, SUM(UTILIDAD_TOTAL) AS utilidad
            FROM VENDIDO_PRODUCTOS
            GROUP BY IDX_FACTURA
        ) VP ON F.ID_FACTURA = VP.IDX_FACTURA
        WHERE (F.ANULADO IS NULL OR F.ANULADO <> 1)   -- ← excluye anuladas
    ),
    cte_compras AS (
        SELECT CONVERT(DATE, FECHA_COMPRA) AS fecha, COSTO_TOTAL
        FROM COMPRAS
    ),
    cte_gastos AS (
        SELECT CONVERT(DATE, FECHA_MOVIMIENTO) AS fecha, VALOR
        FROM MOVIMIENTOS_CAJA
        WHERE IDX_TIPO_MOVIMIENTO = 2
    ),
    cte_abonos AS (
        SELECT CONVERT(DATE, FECHA_ABONO) AS fecha, VALOR_ABONADO
        FROM DETALLE_ABONOS_VENTAS
    )

    SELECT
        periodo,
        total_ingresos,
        utilidad_bruta,
        total_compras,
        gastos_caja,
        abonos_recibidos,
        total_ingresos - total_compras - gastos_caja AS balance_neto,
        num_facturas,
        clientes_atendidos
    FROM (
        SELECT
            'DIARIO' AS periodo,
            ISNULL((SELECT SUM(COSTO_TOTAL)   FROM cte_ventas WHERE fecha = @hoy), 0) AS total_ingresos,
            ISNULL((SELECT SUM(utilidad)       FROM cte_ventas WHERE fecha = @hoy), 0) AS utilidad_bruta,
            ISNULL((SELECT SUM(COSTO_TOTAL)   FROM cte_compras WHERE fecha = @hoy), 0) AS total_compras,
            ISNULL((SELECT SUM(VALOR)         FROM cte_gastos  WHERE fecha = @hoy), 0) AS gastos_caja,
            ISNULL((SELECT SUM(VALOR_ABONADO) FROM cte_abonos  WHERE fecha = @hoy), 0) AS abonos_recibidos,
            ISNULL((SELECT COUNT(*)           FROM cte_ventas WHERE fecha = @hoy), 0) AS num_facturas,
            ISNULL((SELECT COUNT(DISTINCT IDX_CLIENTE) FROM cte_ventas WHERE fecha = @hoy), 0) AS clientes_atendidos
        UNION ALL
        SELECT
            'SEMANAL',
            ISNULL((SELECT SUM(COSTO_TOTAL)   FROM cte_ventas WHERE fecha BETWEEN @inicio_semana AND @fin_semana), 0),
            ISNULL((SELECT SUM(utilidad)       FROM cte_ventas WHERE fecha BETWEEN @inicio_semana AND @fin_semana), 0),
            ISNULL((SELECT SUM(COSTO_TOTAL)   FROM cte_compras WHERE fecha BETWEEN @inicio_semana AND @fin_semana), 0),
            ISNULL((SELECT SUM(VALOR)         FROM cte_gastos  WHERE fecha BETWEEN @inicio_semana AND @fin_semana), 0),
            ISNULL((SELECT SUM(VALOR_ABONADO) FROM cte_abonos  WHERE fecha BETWEEN @inicio_semana AND @fin_semana), 0),
            ISNULL((SELECT COUNT(*)           FROM cte_ventas WHERE fecha BETWEEN @inicio_semana AND @fin_semana), 0),
            ISNULL((SELECT COUNT(DISTINCT IDX_CLIENTE) FROM cte_ventas WHERE fecha BETWEEN @inicio_semana AND @fin_semana), 0)
        UNION ALL
        SELECT
            'MENSUAL',
            ISNULL((SELECT SUM(COSTO_TOTAL)   FROM cte_ventas WHERE fecha BETWEEN @inicio_mes AND @fin_mes), 0),
            ISNULL((SELECT SUM(utilidad)       FROM cte_ventas WHERE fecha BETWEEN @inicio_mes AND @fin_mes), 0),
            ISNULL((SELECT SUM(COSTO_TOTAL)   FROM cte_compras WHERE fecha BETWEEN @inicio_mes AND @fin_mes), 0),
            ISNULL((SELECT SUM(VALOR)         FROM cte_gastos  WHERE fecha BETWEEN @inicio_mes AND @fin_mes), 0),
            ISNULL((SELECT SUM(VALOR_ABONADO) FROM cte_abonos  WHERE fecha BETWEEN @inicio_mes AND @fin_mes), 0),
            ISNULL((SELECT COUNT(*)           FROM cte_ventas WHERE fecha BETWEEN @inicio_mes AND @fin_mes), 0),
            ISNULL((SELECT COUNT(DISTINCT IDX_CLIENTE) FROM cte_ventas WHERE fecha BETWEEN @inicio_mes AND @fin_mes), 0)
    ) AS resumen;
END
GO


-- ============================================================
-- 4. SP_VENTAS_PRODUCTO_CODIGO — excluye facturas ANULADO = 1
-- ============================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SP_VENTAS_PRODUCTO_CODIGO]
    @codigo_barras VARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @hoy           DATE = CONVERT(DATE, GETDATE());
    DECLARE @inicio_semana DATE = DATEADD(WEEK, DATEDIFF(WEEK, 0, GETDATE()), 0);
    DECLARE @fin_semana    DATE = DATEADD(DAY, 6, @inicio_semana);
    DECLARE @inicio_mes    DATE = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
    DECLARE @fin_mes       DATE = EOMONTH(GETDATE());

    SELECT
        P.PRODUCT_ID                                                    AS producto_id,
        P.CODIGO_BARRAS                                                 AS codigo,
        P.PRODUCTO                                                      AS nombre,
        C.CATEGORIA                                                     AS categoria,
        P.COSTO_X_UNIDAD                                                AS costo_actual,
        P.QUANTITY                                                      AS stock_actual,

        ISNULL(SUM(CASE WHEN CONVERT(DATE, F.FECHA_VENTA) = @hoy
                        THEN VP.QUANTITY       ELSE 0 END), 0)         AS diario_cantidad,
        ISNULL(SUM(CASE WHEN CONVERT(DATE, F.FECHA_VENTA) = @hoy
                        THEN VP.TOTAL_COST     ELSE 0 END), 0)         AS diario_ingresos,
        ISNULL(SUM(CASE WHEN CONVERT(DATE, F.FECHA_VENTA) = @hoy
                        THEN VP.UTILIDAD_TOTAL ELSE 0 END), 0)         AS diario_utilidad,

        ISNULL(SUM(CASE WHEN CONVERT(DATE, F.FECHA_VENTA)
                             BETWEEN @inicio_semana AND @fin_semana
                        THEN VP.QUANTITY       ELSE 0 END), 0)         AS semanal_cantidad,
        ISNULL(SUM(CASE WHEN CONVERT(DATE, F.FECHA_VENTA)
                             BETWEEN @inicio_semana AND @fin_semana
                        THEN VP.TOTAL_COST     ELSE 0 END), 0)         AS semanal_ingresos,
        ISNULL(SUM(CASE WHEN CONVERT(DATE, F.FECHA_VENTA)
                             BETWEEN @inicio_semana AND @fin_semana
                        THEN VP.UTILIDAD_TOTAL ELSE 0 END), 0)         AS semanal_utilidad,

        ISNULL(SUM(CASE WHEN CONVERT(DATE, F.FECHA_VENTA)
                             BETWEEN @inicio_mes AND @fin_mes
                        THEN VP.QUANTITY       ELSE 0 END), 0)         AS mensual_cantidad,
        ISNULL(SUM(CASE WHEN CONVERT(DATE, F.FECHA_VENTA)
                             BETWEEN @inicio_mes AND @fin_mes
                        THEN VP.TOTAL_COST     ELSE 0 END), 0)         AS mensual_ingresos,
        ISNULL(SUM(CASE WHEN CONVERT(DATE, F.FECHA_VENTA)
                             BETWEEN @inicio_mes AND @fin_mes
                        THEN VP.UTILIDAD_TOTAL ELSE 0 END), 0)         AS mensual_utilidad

    FROM PRODUCTOS P
    INNER JOIN CATEGORIAS        C  ON P.IDX_CATEGORIA   = C.CATEGORIA_ID
    LEFT  JOIN VENDIDO_PRODUCTOS VP ON P.PRODUCT_ID       = VP.IDX_PRODUCTO
    -- ← filtrar facturas anuladas en el JOIN para no contaminar los CASE WHEN
    LEFT  JOIN FACTURAS          F  ON VP.IDX_FACTURA     = F.ID_FACTURA
                                   AND (F.ANULADO IS NULL OR F.ANULADO <> 1)

    WHERE (@codigo_barras IS NULL OR @codigo_barras = '0' OR P.CODIGO_BARRAS = @codigo_barras)

    GROUP BY
        P.PRODUCT_ID, P.CODIGO_BARRAS, P.PRODUCTO,
        C.CATEGORIA, P.COSTO_X_UNIDAD, P.QUANTITY

    ORDER BY mensual_ingresos DESC;
END
GO


-- ============================================================
-- 5. SP_TENDENCIA_PRODUCTO — excluye facturas ANULADO = 1
-- ============================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SP_TENDENCIA_PRODUCTO]
    @codigo_barras VARCHAR(MAX) = '0'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @inicio_mes DATE = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
    DECLARE @fin_mes    DATE = EOMONTH(GETDATE());

    SELECT
        CONVERT(DATE, F.FECHA_VENTA) AS fecha,
        P.PRODUCT_ID                 AS producto_id,
        P.CODIGO_BARRAS              AS codigo,
        P.PRODUCTO                   AS nombre,
        SUM(VP.QUANTITY)             AS cantidad_vendida,
        SUM(VP.TOTAL_COST)           AS ingresos,
        SUM(VP.UTILIDAD_TOTAL)       AS utilidad
    FROM VENDIDO_PRODUCTOS VP
    INNER JOIN FACTURAS  F ON VP.IDX_FACTURA  = F.ID_FACTURA
    INNER JOIN PRODUCTOS P ON VP.IDX_PRODUCTO = P.PRODUCT_ID
    WHERE (@codigo_barras = '0' OR P.CODIGO_BARRAS = @codigo_barras)
      AND CONVERT(DATE, F.FECHA_VENTA) BETWEEN @inicio_mes AND @fin_mes
      AND (F.ANULADO IS NULL OR F.ANULADO <> 1)   -- ← excluye anuladas
    GROUP BY CONVERT(DATE, F.FECHA_VENTA), P.PRODUCT_ID, P.CODIGO_BARRAS, P.PRODUCTO
    ORDER BY fecha;
END
GO


-- ============================================================
-- 6. SP_LISTADO_PERIODOS — excluye facturas ANULADO = 1
-- ============================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SP_LISTADO_PERIODOS]
    @periodo VARCHAR(10)   -- 'DIARIO' | 'SEMANAL' | 'MENSUAL'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @hoy           DATE = CONVERT(DATE, GETDATE());
    DECLARE @inicio_semana DATE = DATEADD(WEEK, DATEDIFF(WEEK, 0, GETDATE()), 0);
    DECLARE @fin_semana    DATE = DATEADD(DAY, 6, @inicio_semana);
    DECLARE @inicio_mes    DATE = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
    DECLARE @fin_mes       DATE = EOMONTH(GETDATE());

    DECLARE @f_ini DATE, @f_fin DATE;

    IF @periodo = 'DIARIO'      BEGIN SET @f_ini = @hoy;          SET @f_fin = @hoy;       END
    ELSE IF @periodo = 'SEMANAL' BEGIN SET @f_ini = @inicio_semana; SET @f_fin = @fin_semana; END
    ELSE IF @periodo = 'MENSUAL' BEGIN SET @f_ini = @inicio_mes;   SET @f_fin = @fin_mes;   END
    ELSE BEGIN RAISERROR('Periodo invalido. Use: DIARIO, SEMANAL o MENSUAL', 16, 1); RETURN; END

    -- Resultado 1: Facturas del periodo (excluye anuladas)
    SELECT
        F.ID_FACTURA                                               AS id_factura,
        FORMAT(F.FECHA_VENTA, 'dd/MM/yyyy HH:mm')                 AS fecha_venta,
        CONCAT(CL.NOMBRES, ' ', CL.APELLIDOS)                     AS cliente,
        CL.NUMERO_TELEFONO                                         AS telefono_cliente,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                     AS vendedor,
        FP.FORMA_PAGO                                             AS forma_pago,
        F.COSTO_TOTAL                                             AS total,
        F.VALOR_PAGADO                                            AS pagado,
        F.COSTO_TOTAL - F.VALOR_PAGADO                           AS pendiente,
        F.VALOR_IVA                                               AS valor_iva,
        F.CONSUMIDOR_FINAL                                        AS consumidor_final,
        ISNULL(UP.utilidad_factura, 0)                           AS utilidad_total
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
    WHERE CONVERT(DATE, F.FECHA_VENTA) BETWEEN @f_ini AND @f_fin
      AND (F.ANULADO IS NULL OR F.ANULADO <> 1)   -- ← excluye anuladas
    ORDER BY F.FECHA_VENTA DESC;

    -- Resultado 2: Compras del periodo (sin cambios)
    SELECT
        C.ID_COMPRA                                               AS id_compra,
        FORMAT(C.FECHA_COMPRA, 'dd/MM/yyyy HH:mm')               AS fecha_compra,
        PV.RAZON_SOCIAL                                           AS proveedor,
        PV.TELEFONO                                               AS telefono_proveedor,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                    AS comprador,
        FP.FORMA_PAGO                                            AS forma_pago,
        C.COSTO_TOTAL                                            AS total,
        C.VALOR_PAGADO                                           AS pagado,
        C.COSTO_TOTAL - C.VALOR_PAGADO                          AS pendiente,
        C.PAGO_INICIAL                                           AS pago_inicial
    FROM COMPRAS C
    INNER JOIN PROVEEDORES      PV ON C.IDX_PROVEEDOR            = PV.ID_PROVEEDOR
    INNER JOIN USUARIOS         US ON C.IDX_USUARIO_COMPRADOR    = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES DP ON US.IDX_DATOS_PERSONALES    = DP.DATOS_PERSONALES_ID
    INNER JOIN FORMAS_PAGO      FP ON C.IDX_FORMA_PAGO           = FP.ID_FORMA_PAGO
    WHERE CONVERT(DATE, C.FECHA_COMPRA) BETWEEN @f_ini AND @f_fin
    ORDER BY C.FECHA_COMPRA DESC;
END
GO


-- ============================================================
-- 7. SP_RADAR_STOCK — excluye facturas ANULADO = 1
-- ============================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SP_RADAR_STOCK]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @hoy    DATE = CONVERT(DATE, GETDATE());
    DECLARE @hace30 DATE = DATEADD(DAY, -30, @hoy);

    ;WITH cte_ventas_30d AS (
        SELECT VP.IDX_PRODUCTO, SUM(VP.QUANTITY) AS total_vendido
        FROM VENDIDO_PRODUCTOS VP
        INNER JOIN FACTURAS F ON VP.IDX_FACTURA = F.ID_FACTURA
        WHERE CONVERT(DATE, F.FECHA_VENTA) BETWEEN @hace30 AND @hoy
          AND (F.ANULADO IS NULL OR F.ANULADO <> 1)   -- ← excluye anuladas
        GROUP BY VP.IDX_PRODUCTO
    ),
    cte_base AS (
        SELECT
            P.PRODUCT_ID, P.CODIGO_BARRAS, P.PRODUCTO, C.CATEGORIA,
            P.QUANTITY                                                 AS stock_actual,
            P.COSTO_X_UNIDAD                                          AS costo_actual,
            ISNULL(V.total_vendido, 0)                                AS vendido_30_dias,
            CAST(ISNULL(V.total_vendido, 0) / 30.0 AS DECIMAL(10,2)) AS velocidad_diaria,
            CASE
                WHEN ISNULL(V.total_vendido, 0) = 0 THEN NULL
                ELSE CAST(P.QUANTITY / (ISNULL(V.total_vendido, 0) / 30.0) AS INT)
            END AS dias_hasta_agotarse
        FROM PRODUCTOS P
        INNER JOIN CATEGORIAS C ON P.IDX_CATEGORIA = C.CATEGORIA_ID
        LEFT  JOIN cte_ventas_30d V ON P.PRODUCT_ID = V.IDX_PRODUCTO
        WHERE P.ESTADOS = 1
    )
    SELECT
        PRODUCT_ID          AS producto_id,
        CODIGO_BARRAS       AS codigo,
        PRODUCTO            AS nombre,
        CATEGORIA           AS categoria,
        stock_actual, costo_actual, vendido_30_dias, velocidad_diaria, dias_hasta_agotarse,
        CASE
            WHEN stock_actual = 0                              THEN 'AGOTADO'
            WHEN vendido_30_dias = 0                           THEN 'SIN_MOVIMIENTO'
            WHEN dias_hasta_agotarse < 7                       THEN 'CRITICO'
            WHEN dias_hasta_agotarse < 20                      THEN 'ALERTA'
            ELSE 'OK'
        END AS estado
    FROM cte_base
    ORDER BY
        CASE
            WHEN stock_actual = 0                                          THEN 1
            WHEN vendido_30_dias > 0 AND dias_hasta_agotarse < 7          THEN 2
            WHEN vendido_30_dias > 0 AND dias_hasta_agotarse < 20         THEN 3
            WHEN vendido_30_dias > 0                                       THEN 4
            ELSE 5
        END,
        dias_hasta_agotarse ASC;
END
GO


-- ============================================================
-- 8. SP_CARTERA_CLIENTES — excluye facturas ANULADO = 1
-- ============================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SP_CARTERA_CLIENTES]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        CL.CLIENTE_ID                                              AS cliente_id,
        CONCAT(CL.NOMBRES, ' ', CL.APELLIDOS)                     AS cliente,
        CL.NUMERO_TELEFONO                                         AS telefono,
        CL.SALDO_NEGATIVO                                          AS deuda_total,
        CL.SALDO                                                   AS saldo_favor,
        ISNULL(FP.facturas_pendientes, 0)                         AS facturas_pendientes,
        ISNULL(AB.total_abonado, 0)                               AS total_abonado,
        AB.ultimo_pago,
        CASE
            WHEN AB.ultimo_pago IS NULL THEN NULL
            ELSE DATEDIFF(DAY, AB.ultimo_pago, GETDATE())
        END AS dias_sin_pagar,
        CASE
            WHEN AB.ultimo_pago IS NULL                                    THEN 'SIN_ABONOS'
            WHEN DATEDIFF(DAY, AB.ultimo_pago, GETDATE()) > 30            THEN 'EN_MORA'
            WHEN DATEDIFF(DAY, AB.ultimo_pago, GETDATE()) > 15            THEN 'RIESGO'
            ELSE 'NORMAL'
        END AS estado
    FROM CLIENTES CL

    -- Facturas con pago incompleto (excluye anuladas)
    LEFT JOIN (
        SELECT IDX_CLIENTE, COUNT(ID_FACTURA) AS facturas_pendientes
        FROM FACTURAS
        WHERE IDX_FORMA_PAGO = 2
          AND COSTO_TOTAL > VALOR_PAGADO
          AND (ANULADO IS NULL OR ANULADO <> 1)   -- ← excluye anuladas
        GROUP BY IDX_CLIENTE
    ) FP ON CL.CLIENTE_ID = FP.IDX_CLIENTE

    LEFT JOIN (
        SELECT IDX_CLIENTE, SUM(VALOR_ABONADO) AS total_abonado, MAX(FECHA_ABONO) AS ultimo_pago
        FROM DETALLE_ABONOS_VENTAS
        GROUP BY IDX_CLIENTE
    ) AB ON CL.CLIENTE_ID = AB.IDX_CLIENTE

    WHERE CL.SALDO_NEGATIVO > 0
    ORDER BY
        CASE
            WHEN AB.ultimo_pago IS NULL                             THEN 1
            WHEN DATEDIFF(DAY, AB.ultimo_pago, GETDATE()) > 30     THEN 2
            WHEN DATEDIFF(DAY, AB.ultimo_pago, GETDATE()) > 15     THEN 3
            ELSE 4
        END,
        CL.SALDO_NEGATIVO DESC;
END
GO


-- ============================================================
-- 9. SP_MARGEN_REAL — excluye VENDIDO_PRODUCTOS de facturas ANULADO = 1
-- ============================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SP_MARGEN_REAL]
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH cte_ventas AS (
        SELECT
            VP.IDX_PRODUCTO,
            SUM(VP.QUANTITY)       AS unidades_vendidas,
            SUM(VP.TOTAL_COST)     AS ingresos_totales,
            SUM(VP.UTILIDAD_TOTAL) AS utilidad_total
        FROM VENDIDO_PRODUCTOS VP
        -- ← JOIN para filtrar facturas anuladas (VP no tiene flag propio)
        INNER JOIN FACTURAS F ON VP.IDX_FACTURA = F.ID_FACTURA
        WHERE (F.ANULADO IS NULL OR F.ANULADO <> 1)
        GROUP BY VP.IDX_PRODUCTO
    )
    SELECT
        P.PRODUCT_ID                                               AS producto_id,
        P.CODIGO_BARRAS                                            AS codigo,
        P.PRODUCTO                                                 AS nombre,
        C.CATEGORIA                                                AS categoria,
        P.COSTO_X_UNIDAD                                          AS costo_actual,
        ISNULL(V.unidades_vendidas, 0)                            AS unidades_vendidas,
        ISNULL(V.ingresos_totales,  0)                            AS ingresos_totales,
        ISNULL(V.utilidad_total,    0)                            AS utilidad_total,
        CASE
            WHEN ISNULL(V.unidades_vendidas, 0) = 0 THEN 0
            ELSE CAST(V.ingresos_totales / V.unidades_vendidas AS DECIMAL(18,2))
        END AS precio_prom_venta,
        CASE
            WHEN ISNULL(V.unidades_vendidas, 0) = 0 THEN P.COSTO_X_UNIDAD
            ELSE CAST((V.ingresos_totales - V.utilidad_total) / V.unidades_vendidas AS DECIMAL(18,2))
        END AS costo_prom_vendido,
        CASE
            WHEN ISNULL(V.ingresos_totales, 0) = 0 THEN 0
            ELSE CAST(V.utilidad_total / V.ingresos_totales * 100 AS DECIMAL(5,2))
        END AS margen_pct,
        CASE
            WHEN ISNULL(V.unidades_vendidas, 0) = 0                                          THEN 'SIN_VENTAS'
            WHEN V.utilidad_total / NULLIF(V.ingresos_totales, 0) * 100 < 5                 THEN 'MARGEN_CRITICO'
            WHEN V.utilidad_total / NULLIF(V.ingresos_totales, 0) * 100 < 15                THEN 'MARGEN_BAJO'
            ELSE 'OK'
        END AS estado_margen
    FROM PRODUCTOS P
    INNER JOIN CATEGORIAS C ON P.IDX_CATEGORIA = C.CATEGORIA_ID
    LEFT  JOIN cte_ventas V ON P.PRODUCT_ID    = V.IDX_PRODUCTO
    WHERE P.ESTADOS = 1
    ORDER BY
        CASE
            WHEN ISNULL(V.unidades_vendidas, 0) = 0                                         THEN 4
            WHEN V.utilidad_total / NULLIF(V.ingresos_totales, 0) * 100 < 5                THEN 1
            WHEN V.utilidad_total / NULLIF(V.ingresos_totales, 0) * 100 < 15               THEN 2
            ELSE 3
        END,
        ISNULL(V.ingresos_totales, 0) DESC;
END
GO


-- ============================================================
-- 10. SP_ABONOS_VENTAS — excluye facturas ANULADO = 1 (operación FACTURAS)
-- ============================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SP_ABONOS_VENTAS]
    @OPERACION      VARCHAR(10),
    @ID_DETALLE     NUMERIC(18,0) = NULL,
    @IDX_FACTURA    NUMERIC(18,0) = NULL,
    @IDX_USUARIO    NUMERIC(18,0) = NULL,
    @IDX_CLIENTE    NUMERIC(18,0) = NULL,
    @IDX_FORMA_PAGO NUMERIC(18,0) = NULL,
    @VALOR_ABONADO  DECIMAL(18,2) = NULL,
    @COMENTARIO     VARCHAR(100)  = NULL,
    @PAGO_TOTAL     BIT           = NULL,
    @PAGO_PROVEEDOR BIT           = NULL,
    @COMPRA         DECIMAL(18)   = NULL,
    @ESTADO         BIT           = NULL,
    @FECHA_FINAL    DATETIME      = NULL,
    @FECHA_INICIAL  DATETIME      = NULL,
    @PAGINA         INT           = 1,
    @TAMANO_PAGINA  INT           = 10
AS
BEGIN
    SET NOCOUNT ON;

    IF @OPERACION = 'FACTURAS'
    BEGIN
        SELECT
            CL.NOMBRES + ' ' + CL.APELLIDOS   AS NOMBRES,
            (FC.COSTO_TOTAL - FC.VALOR_PAGADO) AS RESTANTE,
            FC.COSTO_TOTAL,
            FC.FECHA_VENTA,
            FC.IDX_CLIENTE,
            FC.ID_FACTURA,
            FC.PAGO_INICIAL,
            FP.FORMA_PAGO,
            COUNT(*) OVER()                    AS total_registros
        FROM FACTURAS FC
        INNER JOIN CLIENTES    CL ON FC.IDX_CLIENTE            = CL.CLIENTE_ID
        LEFT  JOIN FORMAS_PAGO FP ON FC.IDX_FORMA_PAGO_INICIAL = FP.ID_FORMA_PAGO
        WHERE FC.IDX_FORMA_PAGO = 2
          AND (FC.ANULADO IS NULL OR FC.ANULADO <> 1)   -- ← excluye anuladas
          AND (@FECHA_INICIAL IS NULL OR FC.FECHA_VENTA > @FECHA_INICIAL)
          AND (@FECHA_FINAL   IS NULL OR FC.FECHA_VENTA < @FECHA_FINAL)
          AND (@IDX_CLIENTE   IS NULL OR FC.IDX_CLIENTE = @IDX_CLIENTE)
        ORDER BY (FC.COSTO_TOTAL - FC.VALOR_PAGADO) DESC
        OFFSET (@PAGINA - 1) * @TAMANO_PAGINA ROWS
        FETCH NEXT @TAMANO_PAGINA ROWS ONLY;
    END

    IF @OPERACION = 'ABONOS'
    BEGIN
        SELECT
            ID_DETALLE, IDX_FACTURA, IDX_USUARIO,
            DP.NOMBRES + ' ' + DP.APELLIDOS AS USUARIO,
            IDX_CLIENTE, IDX_FORMA_PAGO, VALOR_ABONADO,
            COMENTARIO, FECHA_ABONO, FP.FORMA_PAGO
        FROM DETALLE_ABONOS_VENTAS DAV
        INNER JOIN USUARIOS         U  ON DAV.IDX_USUARIO         = U.USUARIO_ID
        INNER JOIN DATOS_PERSONALES DP ON U.IDX_DATOS_PERSONALES  = DP.DATOS_PERSONALES_ID
        LEFT  JOIN FORMAS_PAGO      FP ON DAV.IDX_FORMA_PAGO      = FP.ID_FORMA_PAGO
        WHERE (@IDX_FACTURA IS NULL OR IDX_FACTURA = @IDX_FACTURA)
    END
    ELSE IF @OPERACION = 'INSERT'
    BEGIN
        DECLARE @PAGO_REALIZADO_A_LA_FECHA  DECIMAL(18,2) = (SELECT TOP 1 ISNULL(VALOR_PAGADO,0)    FROM FACTURAS WHERE ID_FACTURA  = @IDX_FACTURA)
        DECLARE @COSTO_TOTAL                DECIMAL(18,2) = (SELECT TOP 1 ISNULL(COSTO_TOTAL,0)     FROM FACTURAS WHERE ID_FACTURA  = @IDX_FACTURA)
        DECLARE @SALDO_NEGATIVO_CLIENTE     DECIMAL(18,2) = (SELECT TOP 1 ISNULL(SALDO_NEGATIVO,0)  FROM CLIENTES WHERE CLIENTE_ID  = @IDX_CLIENTE)
        DECLARE @SALDO_POSITIVO_CLIENTE     DECIMAL(18,2) = (SELECT TOP 1 ISNULL(SALDO,0)           FROM CLIENTES WHERE CLIENTE_ID  = @IDX_CLIENTE)
        DECLARE @caja                       NUMERIC(18,0) = (SELECT TOP 1 ID_CAJA FROM CAJA WHERE IDX_USUARIO = @IDX_USUARIO AND FECHA_CIERRE_CAJA IS NULL)
        DECLARE @PAGO_A_PROVEEDOR           DECIMAL       = @VALOR_ABONADO;

        IF @PAGO_TOTAL = 1
        BEGIN
            UPDATE FACTURAS SET VALOR_PAGADO = @COSTO_TOTAL WHERE ID_FACTURA = @IDX_FACTURA;
            SET @VALOR_ABONADO          = @COSTO_TOTAL - @PAGO_REALIZADO_A_LA_FECHA;
            SET @SALDO_NEGATIVO_CLIENTE = @SALDO_NEGATIVO_CLIENTE - (@COSTO_TOTAL - @PAGO_REALIZADO_A_LA_FECHA);
        END
        ELSE
        BEGIN
            UPDATE FACTURAS
            SET VALOR_PAGADO = ISNULL(VALOR_PAGADO, 0) + @VALOR_ABONADO
            WHERE ID_FACTURA = @IDX_FACTURA;
            SET @SALDO_NEGATIVO_CLIENTE = @SALDO_NEGATIVO_CLIENTE - @VALOR_ABONADO;
        END

        UPDATE CLIENTES
        SET SALDO_NEGATIVO = @SALDO_NEGATIVO_CLIENTE
        WHERE CLIENTE_ID = @IDX_CLIENTE;

        INSERT INTO DETALLE_ABONOS_VENTAS (IDX_FACTURA, IDX_USUARIO, IDX_CLIENTE, IDX_FORMA_PAGO, VALOR_ABONADO, COMENTARIO, ESTADO, IDX_CAJA)
        VALUES (@IDX_FACTURA, @IDX_USUARIO, @IDX_CLIENTE, @IDX_FORMA_PAGO, @VALOR_ABONADO, @COMENTARIO, 1, @caja)
    END
END
GO


-- ============================================================
-- 11. SP_BALANCE_DIARIO_IMPRIMIBLE — excluye facturas ANULADO = 1
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

    -- Resultado 1: Ventas del rango (excluye anuladas)
    SELECT
        F.ID_FACTURA                                               AS id_factura,
        FORMAT(F.FECHA_VENTA, 'dd/MM/yyyy HH:mm')                 AS fecha_venta,
        CONCAT(CL.NOMBRES, ' ', CL.APELLIDOS)                     AS cliente,
        FP.FORMA_PAGO                                             AS forma_pago,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                     AS vendedor,
        F.COSTO_TOTAL                                             AS total,
        F.VALOR_PAGADO                                            AS pagado,
        CASE WHEN F.IDX_FORMA_PAGO = 2
             THEN F.COSTO_TOTAL - F.VALOR_PAGADO ELSE 0 END       AS pendiente,
        ISNULL(UP.utilidad_factura, 0)                            AS utilidad_total
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
      AND (F.ANULADO IS NULL OR F.ANULADO <> 1)   -- ← excluye anuladas
    ORDER BY F.FECHA_VENTA;

    -- Resultado 2: Compras del rango (sin cambios)
    SELECT
        C.ID_COMPRA                                               AS id_compra,
        FORMAT(C.FECHA_COMPRA, 'dd/MM/yyyy HH:mm')               AS fecha_compra,
        PV.RAZON_SOCIAL                                           AS proveedor,
        FP.FORMA_PAGO                                            AS forma_pago,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                    AS comprador,
        C.COSTO_TOTAL                                            AS total,
        C.VALOR_PAGADO                                           AS pagado,
        C.COSTO_TOTAL - C.VALOR_PAGADO                          AS pendiente
    FROM COMPRAS C
    INNER JOIN PROVEEDORES      PV ON C.IDX_PROVEEDOR            = PV.ID_PROVEEDOR
    INNER JOIN USUARIOS         US ON C.IDX_USUARIO_COMPRADOR    = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES DP ON US.IDX_DATOS_PERSONALES    = DP.DATOS_PERSONALES_ID
    INNER JOIN FORMAS_PAGO      FP ON C.IDX_FORMA_PAGO           = FP.ID_FORMA_PAGO
    WHERE C.FECHA_COMPRA BETWEEN @fecha_inicio AND @fecha_fin
    ORDER BY C.FECHA_COMPRA;

    -- Resultado 3: Gastos (sin cambios)
    SELECT
        FORMAT(MC.FECHA_MOVIMIENTO, 'dd/MM/yyyy HH:mm')          AS fecha,
        CASE WHEN MC.IDX_GASTO IS NULL OR MC.IDX_GASTO = 0
             THEN 'Sin categoria' ELSE G.NOMBRE END               AS categoria_gasto,
        ISNULL(MC.DESCRIPCION, '')                                AS descripcion,
        FP.FORMA_PAGO                                            AS forma_pago,
        MC.VALOR                                                  AS valor
    FROM MOVIMIENTOS_CAJA MC
    LEFT  JOIN GASTOS      G  ON MC.IDX_GASTO        = G.ID_GASTO
    INNER JOIN FORMAS_PAGO FP ON MC.IDX_DENOMINACION = FP.ID_FORMA_PAGO
    WHERE MC.IDX_TIPO_MOVIMIENTO = 2
      AND MC.FECHA_MOVIMIENTO BETWEEN @fecha_inicio AND @fecha_fin
    ORDER BY MC.FECHA_MOVIMIENTO;

    -- Resultado 4: Abonos recibidos de clientes (sin cambios)
    SELECT
        FORMAT(DAV.FECHA_ABONO, 'dd/MM/yyyy HH:mm')              AS fecha_abono,
        DAV.IDX_FACTURA                                           AS id_factura,
        CONCAT(CL.NOMBRES, ' ', CL.APELLIDOS)                    AS cliente,
        ISNULL(FP.FORMA_PAGO, 'N/A')                             AS forma_pago,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                    AS usuario,
        DAV.VALOR_ABONADO                                         AS valor_abonado
    FROM DETALLE_ABONOS_VENTAS DAV
    INNER JOIN CLIENTES         CL ON DAV.IDX_CLIENTE         = CL.CLIENTE_ID
    INNER JOIN USUARIOS         US ON DAV.IDX_USUARIO         = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES DP ON US.IDX_DATOS_PERSONALES = DP.DATOS_PERSONALES_ID
    LEFT  JOIN FORMAS_PAGO      FP ON DAV.IDX_FORMA_PAGO      = FP.ID_FORMA_PAGO
    WHERE DAV.FECHA_ABONO BETWEEN @fecha_inicio AND @fecha_fin
    ORDER BY DAV.FECHA_ABONO;

    -- Resultado 5: Abonos pagados a proveedores (sin cambios)
    SELECT
        FORMAT(DAC.FECHA_ABONO, 'dd/MM/yyyy HH:mm')              AS fecha_abono,
        DAC.IDX_COMPRA                                            AS id_compra,
        PV.RAZON_SOCIAL                                           AS proveedor,
        ISNULL(FP.FORMA_PAGO, 'N/A')                             AS forma_pago,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                    AS usuario,
        DAC.VALOR_ABONADO                                         AS valor_abonado
    FROM DETALLE_ABONOS_COMPRAS DAC
    INNER JOIN COMPRAS           C  ON DAC.IDX_COMPRA            = C.ID_COMPRA
    INNER JOIN PROVEEDORES       PV ON C.IDX_PROVEEDOR           = PV.ID_PROVEEDOR
    INNER JOIN USUARIOS          US ON DAC.IDX_USUARIO           = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES  DP ON US.IDX_DATOS_PERSONALES   = DP.DATOS_PERSONALES_ID
    LEFT  JOIN FORMAS_PAGO       FP ON DAC.IDX_FORMA_PAGO        = FP.ID_FORMA_PAGO
    WHERE DAC.FECHA_ABONO BETWEEN @fecha_inicio AND @fecha_fin
    ORDER BY DAC.FECHA_ABONO;

    -- Resultado 6: Resumen de productos vendidos (excluye anuladas)
    SELECT
        P.CODIGO_BARRAS                                           AS codigo,
        P.PRODUCTO                                                AS nombre,
        P.COSTO_X_UNIDAD                                          AS costo_actual,
        SUM(VP.QUANTITY)                                          AS cantidad_vendida,
        SUM(VP.TOTAL_COST)                                        AS ingresos,
        SUM(VP.UTILIDAD_TOTAL)                                    AS utilidad
    FROM VENDIDO_PRODUCTOS VP
    INNER JOIN FACTURAS  F ON VP.IDX_FACTURA  = F.ID_FACTURA
    INNER JOIN PRODUCTOS P ON VP.IDX_PRODUCTO = P.PRODUCT_ID
    WHERE F.FECHA_VENTA BETWEEN @fecha_inicio AND @fecha_fin
      AND (F.ANULADO IS NULL OR F.ANULADO <> 1)   -- ← excluye anuladas
    GROUP BY P.PRODUCT_ID, P.CODIGO_BARRAS, P.PRODUCTO, P.COSTO_X_UNIDAD
    ORDER BY SUM(VP.QUANTITY) DESC;
END
GO


-- ============================================================
-- 12. SP_UTILIDADES_ACCIONES — excluye facturas ANULADO = 1
--     (cuadre de caja / informe-caja)
-- ============================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SP_UTILIDADES_ACCIONES]
    @fecha_inicial DATETIME,
    @fecha_final   DATETIME
AS
BEGIN
    declare @fecha_gastos_inicial datetime = @fecha_inicial,
            @fecha_gastos_final   datetime = @fecha_final;

    set @fecha_inicial = '01/01/2025';
    set @fecha_final   = '01/01/2030';

    -- Ganancia Bruta de ventas (excluye facturas anuladas)
    DECLARE @ganancia_bruta_ventas DECIMAL =
    (
        ISNULL(
            (
                SELECT ISNULL(SUM(COSTO_TOTAL), 0)
                     + ISNULL((
                           SELECT SUM(PAGO_INICIAL)
                           FROM FACTURAS
                           WHERE IDX_FORMA_PAGO = 2
                             AND @fecha_inicial <= FECHA_VENTA AND @fecha_final >= FECHA_VENTA
                             AND (ANULADO IS NULL OR ANULADO <> 1)   -- ← excluye anuladas
                       ), 0)
                FROM FACTURAS
                WHERE IDX_FORMA_PAGO <> 2
                  AND @fecha_inicial <= FECHA_VENTA AND @fecha_final >= FECHA_VENTA
                  AND (ANULADO IS NULL OR ANULADO <> 1)              -- ← excluye anuladas
            ),
        0)
    ),

    -- Abonos recibidos (no depende de FACTURAS directamente)
    @ganancia_bruta_abonos DECIMAL =
    (
        ISNULL(
            (SELECT SUM(VALOR_ABONADO)
             FROM DETALLE_ABONOS_VENTAS
             WHERE @fecha_inicial <= FECHA_ABONO AND @fecha_final >= FECHA_ABONO),
        0)
    );

    -- Egresos
    DECLARE @egresos_gastos DECIMAL =
    (
        ISNULL(
            (SELECT SUM(VALOR)
             FROM MOVIMIENTOS_CAJA
             WHERE IDX_GASTO <> 0
               AND IDX_TIPO_MOVIMIENTO = 2
               AND @fecha_gastos_inicial <= FECHA_MOVIMIENTO AND @fecha_gastos_final >= FECHA_MOVIMIENTO),
        0)
    ),
    @egresos_compras DECIMAL =
    (
        ISNULL(
            (
                SELECT ISNULL(SUM(COSTO_TOTAL), 0)
                     + ISNULL((
                           SELECT SUM(PAGO_INICIAL)
                           FROM COMPRAS
                           WHERE IDX_FORMA_PAGO = 2
                             AND @fecha_inicial <= FECHA_COMPRA AND @fecha_final >= FECHA_COMPRA
                       ), 0)
                FROM COMPRAS
                WHERE @fecha_inicial <= FECHA_COMPRA AND @fecha_final >= FECHA_COMPRA
                  AND IDX_FORMA_PAGO <> 2
            ),
        0)
    ),
    @egresos_abonos_hechos DECIMAL =
    (
        ISNULL(
            (SELECT SUM(VALOR_ABONADO)
             FROM DETALLE_ABONOS_COMPRAS
             WHERE @fecha_inicial <= FECHA_ABONO AND @fecha_final >= FECHA_ABONO),
        0)
    );

    DECLARE @movimientos_positivos DECIMAL = (
        SELECT ISNULL(SUM(VALOR), 0)
        FROM MOVIMIENTOS_CAJA
        WHERE IDX_TIPO_MOVIMIENTO = 1
          AND @fecha_inicial <= FECHA_MOVIMIENTO AND @fecha_final >= FECHA_MOVIMIENTO
    );

    DECLARE @movimientos_negativos DECIMAL = (
        SELECT ISNULL(SUM(VALOR), 0)
        FROM MOVIMIENTOS_CAJA
        WHERE IDX_TIPO_MOVIMIENTO = 2
          AND @fecha_inicial <= FECHA_MOVIMIENTO AND @fecha_final >= FECHA_MOVIMIENTO
    );

    -- Utilidad Neta
    DECLARE @ganancia_neta DECIMAL =
        (@ganancia_bruta_ventas + @ganancia_bruta_abonos)
        - (@egresos_gastos + @egresos_compras + @egresos_abonos_hechos);

    -- Valor por Inventario
    DECLARE @total_por_productos_inventario DECIMAL =
    (
        ISNULL(
            (SELECT SUM(total_por_producto)
             FROM (
                 SELECT SUM(QUANTITY * COSTO_X_UNIDAD) AS total_por_producto
                 FROM PRODUCTOS
                 GROUP BY PRODUCTO
             ) AS sub),
        0)
    );

    DECLARE @total_me_deben  DECIMAL = (SELECT SUM(ISNULL(SALDO_NEGATIVO, 0)) FROM CLIENTES);
    DECLARE @total_debo_clientes   DECIMAL = (SELECT SUM(ISNULL(SALDO, 0)) FROM CLIENTES);
    DECLARE @total_debo_proveedores DECIMAL = (SELECT SUM(ISNULL(SALDO_PENDIENTE, 0)) FROM PROVEEDORES);
    DECLARE @total_debo DECIMAL = @total_debo_proveedores + @total_debo_clientes;

    -- Resultado 1: Saldo general
    SELECT
        @ganancia_bruta_ventas              AS ganancia_bruta_ventas,
        @ganancia_bruta_abonos              AS ganancia_bruta_abonos,
        @egresos_abonos_hechos              AS egresos_abonos_hechos,
        @egresos_compras                    AS egresos_compras,
        @egresos_gastos                     AS egresos_gastos,
        @ganancia_neta                      AS ganancia_neta,
        @total_debo                         AS debo,
        @total_me_deben                     AS me_deben,
        @movimientos_negativos              AS movimientos_negativos,
        @movimientos_positivos              AS movimienetos_positivos,
        @total_por_productos_inventario     AS total_por_productos_inventario,
        (@ganancia_neta + @total_por_productos_inventario) AS patrimonio;

    -- Resultado 2: Cajas del periodo
    SELECT
        ID_CAJA             AS id_caja,
        FECHA_APERTURA_CAJA AS fecha_apertura,
        FECHA_CIERRE_CAJA   AS fecha_cierre,
        DATOS_PERSONALES.NOMBRES
    FROM CAJA
    INNER JOIN USUARIOS         ON CAJA.IDX_USUARIO             = USUARIOS.USUARIO_ID
    INNER JOIN DATOS_PERSONALES ON USUARIOS.IDX_DATOS_PERSONALES = DATOS_PERSONALES.DATOS_PERSONALES_ID
    WHERE FECHA_APERTURA_CAJA >= @fecha_gastos_inicial
      AND FECHA_CIERRE_CAJA   <= @fecha_gastos_final
    ORDER BY id_caja DESC;

    -- Resultado 3: Utilidad de productos en el periodo (excluye anuladas via JOIN)
    SELECT ISNULL(SUM(VP.UTILIDAD_TOTAL), 0) AS utilidad_total
    FROM VENDIDO_PRODUCTOS VP
    INNER JOIN FACTURAS F ON VP.IDX_FACTURA = F.ID_FACTURA
    WHERE VP.FECHA_CREACION >= @fecha_gastos_inicial
      AND VP.FECHA_CREACION <= @fecha_gastos_final
      AND (F.ANULADO IS NULL OR F.ANULADO <> 1);   -- ← excluye anuladas

    -- Resultado 4: Resumen de productos vendidos en el periodo (excluye anuladas)
    SELECT
        P.PRODUCT_ID      AS id,
        P.QUANTITY        AS disponible,
        P.PRODUCTO        AS producto,
        ISNULL(VS.cantidad_vendida,       0) AS cantidad_vendida,
        ISNULL(VS.utilidad_generada,      0) AS utilidad_generada,
        ISNULL(VSF.cantidad_vendida_mes,  0) AS cantidad_vendida_mes,
        ISNULL(VSF.utilidad_generada_mes, 0) AS utilidad_generada_mes
    FROM PRODUCTOS P
    LEFT JOIN (
        SELECT VP.IDX_PRODUCTO,
               SUM(VP.QUANTITY)       AS cantidad_vendida,
               SUM(VP.UTILIDAD_TOTAL) AS utilidad_generada
        FROM VENDIDO_PRODUCTOS VP
        INNER JOIN FACTURAS F ON VP.IDX_FACTURA = F.ID_FACTURA
        WHERE VP.FECHA_CREACION BETWEEN @fecha_inicial AND @fecha_final
          AND (F.ANULADO IS NULL OR F.ANULADO <> 1)   -- ← excluye anuladas
        GROUP BY VP.IDX_PRODUCTO
    ) VS ON VS.IDX_PRODUCTO = P.PRODUCT_ID
    LEFT JOIN (
        SELECT VP.IDX_PRODUCTO,
               SUM(VP.QUANTITY)       AS cantidad_vendida_mes,
               SUM(VP.UTILIDAD_TOTAL) AS utilidad_generada_mes
        FROM VENDIDO_PRODUCTOS VP
        INNER JOIN FACTURAS F ON VP.IDX_FACTURA = F.ID_FACTURA
        WHERE VP.FECHA_CREACION BETWEEN @fecha_gastos_inicial AND @fecha_gastos_final
          AND (F.ANULADO IS NULL OR F.ANULADO <> 1)   -- ← excluye anuladas
        GROUP BY VP.IDX_PRODUCTO
    ) VSF ON VSF.IDX_PRODUCTO = P.PRODUCT_ID
    ORDER BY utilidad_generada DESC;

    -- Resultado 5: Cuadre por forma de pago (excluye facturas anuladas en VENTAS y PAGOS_INICIALES_RECIBIDOS)
    WITH
    VENTAS AS (
        SELECT IDX_FORMA_PAGO, SUM(COSTO_TOTAL) AS total_ventas
        FROM FACTURAS
        WHERE @fecha_inicial <= FECHA_VENTA AND @fecha_final >= FECHA_VENTA
          AND (ANULADO IS NULL OR ANULADO <> 1)   -- ← excluye anuladas
        GROUP BY IDX_FORMA_PAGO
    ),
    PAGOS_INICIALES_RECIBIDOS AS (
        SELECT IDX_FORMA_PAGO_INICIAL, SUM(PAGO_INICIAL) AS total_pagos_iniciales
        FROM FACTURAS
        WHERE @fecha_inicial <= FECHA_VENTA AND @fecha_final >= FECHA_VENTA
          AND (ANULADO IS NULL OR ANULADO <> 1)   -- ← excluye anuladas
        GROUP BY IDX_FORMA_PAGO_INICIAL
    ),
    PAGOS_INICIALES_HECHOS AS (
        SELECT IDX_FORMA_PAGO_INICIAL, SUM(PAGO_INICIAL) AS total_pagos_iniciales
        FROM COMPRAS
        WHERE @fecha_inicial <= FECHA_COMPRA AND @fecha_final >= FECHA_COMPRA
        GROUP BY IDX_FORMA_PAGO_INICIAL
    ),
    ABONOS_VENTAS AS (
        SELECT IDX_FORMA_PAGO, SUM(VALOR_ABONADO) AS total_abonos_ventas
        FROM DETALLE_ABONOS_VENTAS
        WHERE @fecha_inicial <= FECHA_ABONO AND @fecha_final >= FECHA_ABONO
        GROUP BY IDX_FORMA_PAGO
    ),
    COMPRAS_HECHAS AS (
        SELECT IDX_FORMA_PAGO, SUM(COSTO_TOTAL) AS total_compras
        FROM COMPRAS
        WHERE @fecha_inicial <= FECHA_COMPRA AND @fecha_final >= FECHA_COMPRA
        GROUP BY IDX_FORMA_PAGO
    ),
    ABONOS_COMPRAS AS (
        SELECT IDX_FORMA_PAGO, SUM(VALOR_ABONADO) AS total_abonos_compras
        FROM DETALLE_ABONOS_COMPRAS
        WHERE @fecha_inicial <= FECHA_ABONO AND @fecha_final >= FECHA_ABONO
        GROUP BY IDX_FORMA_PAGO
    ),
    APERTURA_CAJA AS (
        SELECT IDX_DENOMINACION, SUM(SALDO) AS total_apertura
        FROM SALDOS_APERTURA_CAJA
        WHERE @fecha_inicial <= FECHA AND @fecha_final >= FECHA
        GROUP BY IDX_DENOMINACION
    ),
    MOVIMIENTOS_CAJAS AS (
        SELECT
            IDX_DENOMINACION,
            SUM(CASE WHEN IDX_TIPO_MOVIMIENTO = 1 THEN VALOR ELSE 0 END) AS entradas,
            SUM(CASE WHEN IDX_TIPO_MOVIMIENTO = 2 THEN VALOR ELSE 0 END) AS salidas
        FROM MOVIMIENTOS_CAJA
        WHERE @fecha_inicial <= FECHA_MOVIMIENTO AND @fecha_final >= FECHA_MOVIMIENTO
        GROUP BY IDX_DENOMINACION
    )
    SELECT
        FP.ID_FORMA_PAGO                                          AS id_pago,
        FP.FORMA_PAGO                                             AS forma_pago,
        ISNULL(V.total_ventas,                  0)                AS valor_ventas,
        ISNULL(AV.total_abonos_ventas,          0)                AS valor_abonos_ventas,
        ISNULL(C.total_compras,                 0)                AS valor_compras,
        ISNULL(AC.total_abonos_compras,         0)                AS valor_abonos_compras,
        ISNULL(ACJ.total_apertura,              0)                AS saldo_apertura,
        ISNULL(MC.entradas,                     0)                AS movimientos_entrada,
        ISNULL(MC.salidas,                      0)                AS movimientos_salida,
        ISNULL(P_I.total_pagos_iniciales,       0)                AS pago_inicial_recibido,
        ISNULL(P_IH.total_pagos_iniciales,      0)                AS pago_inicial_hecho,
        (
            ISNULL(V.total_ventas,              0) +
            ISNULL(AV.total_abonos_ventas,      0) +
            ISNULL(ACJ.total_apertura,          0) +
            ISNULL(MC.entradas,                 0) +
            ISNULL(P_I.total_pagos_iniciales,   0)
        ) - (
            ISNULL(C.total_compras,             0) +
            ISNULL(AC.total_abonos_compras,     0) +
            ISNULL(MC.salidas,                  0) +
            ISNULL(P_IH.total_pagos_iniciales,  0)
        )                                                         AS dinero_actual,
        BIT_CAJA
    FROM FORMAS_PAGO FP
    LEFT JOIN VENTAS                   V    ON V.IDX_FORMA_PAGO              = FP.ID_FORMA_PAGO
    LEFT JOIN ABONOS_VENTAS            AV   ON AV.IDX_FORMA_PAGO             = FP.ID_FORMA_PAGO
    LEFT JOIN COMPRAS_HECHAS           C    ON C.IDX_FORMA_PAGO              = FP.ID_FORMA_PAGO
    LEFT JOIN ABONOS_COMPRAS           AC   ON AC.IDX_FORMA_PAGO             = FP.ID_FORMA_PAGO
    LEFT JOIN APERTURA_CAJA            ACJ  ON ACJ.IDX_DENOMINACION          = FP.ID_FORMA_PAGO
    LEFT JOIN MOVIMIENTOS_CAJAS        MC   ON MC.IDX_DENOMINACION           = FP.ID_FORMA_PAGO
    LEFT JOIN PAGOS_INICIALES_RECIBIDOS P_I  ON P_I.IDX_FORMA_PAGO_INICIAL  = FP.ID_FORMA_PAGO
    LEFT JOIN PAGOS_INICIALES_HECHOS   P_IH ON P_IH.IDX_FORMA_PAGO_INICIAL  = FP.ID_FORMA_PAGO;

    -- Resultado 6: Saldos de clientes
    SELECT
        NOMBRES + ' ' + APELLIDOS AS cliente,
        SALDO_NEGATIVO            AS saldo_negativo,
        SALDO                     AS saldo_positivo
    FROM CLIENTES
    ORDER BY saldo_negativo DESC;

    -- Resultado 7: Saldos de proveedores
    SELECT
        RAZON_SOCIAL              AS proveedor,
        ISNULL(SALDO_PENDIENTE,0) AS saldo_pendiente
    FROM PROVEEDORES
    ORDER BY saldo_pendiente DESC;
END
GO


-- ============================================================
-- 13. SP_CARGAINICIAL_DASHBOARD — excluye facturas ANULADO = 1
-- ============================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SP_CARGAINICIAL_DASHBOARD]
AS
BEGIN
    -- Ventas por mes (excluye anuladas)
    declare @anio INT = YEAR(GETDATE());
    WITH Meses AS (
        SELECT 1 AS MES, 'Ene' AS MES_NOMBRE UNION SELECT 2, 'Feb' UNION SELECT 3, 'Mar'
        UNION SELECT 4, 'Abr'  UNION SELECT 5, 'May' UNION SELECT 6, 'Jun'
        UNION SELECT 7, 'Jul'  UNION SELECT 8, 'Ago' UNION SELECT 9, 'Sep'
        UNION SELECT 10, 'Oct' UNION SELECT 11, 'Nov' UNION SELECT 12, 'Dic'
    )
    SELECT SUM(f.COSTO_TOTAL) AS TOTAL, m.MES, m.MES_NOMBRE, YEAR(f.FECHA_VENTA) AS ANIO
    FROM Meses m
    LEFT JOIN FACTURAS f ON MONTH(f.FECHA_VENTA) = m.MES
                         AND YEAR(f.FECHA_VENTA)  = @anio
                         AND (f.ANULADO IS NULL OR f.ANULADO <> 1)   -- ← excluye anuladas
    GROUP BY m.MES, m.MES_NOMBRE, YEAR(f.FECHA_VENTA)
    ORDER BY m.MES;

    -- Ventas por día (excluye anuladas)
    SELECT SUM(COSTO_TOTAL) AS TOTAL, CONVERT(DATE, FECHA_VENTA) AS FECHA
    FROM FACTURAS
    WHERE CONVERT(DATE, FECHA_VENTA) = CONVERT(DATE, GETDATE())
      AND (ANULADO IS NULL OR ANULADO <> 1)   -- ← excluye anuladas
    GROUP BY CONVERT(DATE, FECHA_VENTA);

    -- Citas para hoy
    SELECT COUNT(APPT_ID) AS CITAS_HOY FROM CITAS
    WHERE CONVERT(DATE, FECHA_CITA) = CONVERT(DATE, GETDATE());

    -- Citas atendidas hoy
    SELECT COUNT(APPT_ID) AS CITAS_ATENDIDAS_HOY FROM CITAS
    INNER JOIN CITAS_ESTADOS ON CITAS.IDX_ESTADOS = CITAS_ESTADOS.ESTADOS_ID
    WHERE CONVERT(DATE, FECHA_CITA) = CONVERT(DATE, GETDATE())
      AND CITAS_ESTADOS.CITAS_ESTADOS = 'ASISTIDO';

    -- Facturas del día (excluye anuladas)
    SELECT COUNT(ID_FACTURA) AS TOTAL_FACTUTAS FROM FACTURAS
    WHERE CONVERT(DATE, FECHA_VENTA) = CONVERT(DATE, GETDATE())
      AND (ANULADO IS NULL OR ANULADO <> 1);   -- ← excluye anuladas

    SELECT CLIENTE_ID, NOMBRES, APELLIDOS FROM CLIENTES;

    SELECT SERVICIO_ID, SERVICIO, COSTO_REGULAR FROM SERVICIOS WHERE ESTADOS = 1;

    SELECT
        CI.APPT_ID, CI.IDX_CLIENTE, CI.IDX_ESTADOS, CI.IDX_SERVICIO, CI.IDX_USUARIO_CREADOR, CI.FECHA_CITA,
        (CL.NOMBRES + CL.APELLIDOS) AS CLIENTE, CL.NUMERO_TELEFONO,
        DP.NOMBRES,
        SE.SERVICIO,
        CIE.CITAS_ESTADOS,
        CONVERT(varchar(15), CAST(CI.FECHA_CITA AS TIME), 100) AS hora
    FROM CITAS CI
    INNER JOIN CLIENTES         CL  ON CI.IDX_CLIENTE          = CL.CLIENTE_ID
    INNER JOIN USUARIOS         US  ON CI.IDX_USUARIO_CREADOR  = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES DP  ON US.IDX_DATOS_PERSONALES = DP.DATOS_PERSONALES_ID
    INNER JOIN SERVICIOS        SE  ON CI.IDX_SERVICIO         = SE.SERVICIO_ID
    INNER JOIN CITAS_ESTADOS    CIE ON CI.IDX_ESTADOS          = CIE.ESTADOS_ID
    ORDER BY FECHA_CITA DESC;

    -- Gastos por mes
    WITH Meses AS (
        SELECT 1 AS MES, 'Ene' AS MES_NOMBRE UNION SELECT 2, 'Feb' UNION SELECT 3, 'Mar'
        UNION SELECT 4, 'Abr'  UNION SELECT 5, 'May' UNION SELECT 6, 'Jun'
        UNION SELECT 7, 'Jul'  UNION SELECT 8, 'Ago' UNION SELECT 9, 'Sep'
        UNION SELECT 10, 'Oct' UNION SELECT 11, 'Nov' UNION SELECT 12, 'Dic'
    )
    SELECT SUM(MC.VALOR) AS TOTAL, m.MES, m.MES_NOMBRE
    FROM Meses m
    LEFT JOIN MOVIMIENTOS_CAJA MC ON MONTH(MC.FECHA_MOVIMIENTO) = m.MES
                                  AND YEAR(MC.FECHA_MOVIMIENTO)  = @anio
                                  AND MC.IDX_TIPO_MOVIMIENTO = 2
    GROUP BY m.MES, m.MES_NOMBRE
    ORDER BY m.MES;
END
GO
