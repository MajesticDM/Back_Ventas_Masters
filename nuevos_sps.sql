USE [MOTO_MASTERS]
GO

-- ============================================================
-- SP_BALANCE_PERIODOS
-- Retorna balance financiero diario, semanal y mensual
-- en una sola llamada.
--
-- Columnas retornadas:
--   periodo            : DIARIO | SEMANAL | MENSUAL
--   total_ingresos     : Suma de FACTURAS.COSTO_TOTAL
--   utilidad_bruta     : Suma de utilidad ya calculada en VENDIDO_PRODUCTOS
--   total_compras      : Suma de COMPRAS.COSTO_TOTAL
--   gastos_caja        : Egresos manuales en MOVIMIENTOS_CAJA
--   abonos_recibidos   : Pagos de cuotas recibidos en DETALLE_ABONOS_VENTAS
--   balance_neto       : total_ingresos - total_compras - gastos_caja
--   num_facturas       : Facturas emitidas en el periodo
--   clientes_atendidos : Clientes únicos en el periodo
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
    -- Semana: lunes a domingo (DATEDIFF(WEEK,0,...) usa lunes como inicio porque el dia 0 fue lunes)
    DECLARE @inicio_semana DATE = DATEADD(WEEK, DATEDIFF(WEEK, 0, GETDATE()), 0);
    DECLARE @fin_semana    DATE = DATEADD(DAY, 6, @inicio_semana);
    DECLARE @inicio_mes    DATE = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
    DECLARE @fin_mes       DATE = EOMONTH(GETDATE());

    -- Base de ventas con utilidad pre-calculada
    ;WITH cte_ventas AS (
        SELECT
            F.ID_FACTURA,
            F.COSTO_TOTAL,
            F.IDX_CLIENTE,
            CONVERT(DATE, F.FECHA_VENTA)  AS fecha,
            ISNULL(VP.utilidad, 0)        AS utilidad
        FROM FACTURAS F
        LEFT JOIN (
            SELECT IDX_FACTURA, SUM(UTILIDAD_TOTAL) AS utilidad
            FROM VENDIDO_PRODUCTOS
            GROUP BY IDX_FACTURA
        ) VP ON F.ID_FACTURA = VP.IDX_FACTURA
    ),
    cte_compras AS (
        SELECT CONVERT(DATE, FECHA_COMPRA)    AS fecha, COSTO_TOTAL
        FROM COMPRAS
    ),
    cte_gastos AS (
        SELECT CONVERT(DATE, FECHA_MOVIMIENTO) AS fecha, VALOR
        FROM MOVIMIENTOS_CAJA
        WHERE IDX_TIPO_MOVIMIENTO = 2   -- 2 = egreso
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
            ISNULL((SELECT SUM(COSTO_TOTAL)            FROM cte_ventas  WHERE fecha = @hoy), 0) AS total_ingresos,
            ISNULL((SELECT SUM(utilidad)               FROM cte_ventas  WHERE fecha = @hoy), 0) AS utilidad_bruta,
            ISNULL((SELECT SUM(COSTO_TOTAL)            FROM cte_compras WHERE fecha = @hoy), 0) AS total_compras,
            ISNULL((SELECT SUM(VALOR)                  FROM cte_gastos  WHERE fecha = @hoy), 0) AS gastos_caja,
            ISNULL((SELECT SUM(VALOR_ABONADO)          FROM cte_abonos  WHERE fecha = @hoy), 0) AS abonos_recibidos,
            ISNULL((SELECT COUNT(ID_FACTURA)           FROM cte_ventas  WHERE fecha = @hoy), 0) AS num_facturas,
            ISNULL((SELECT COUNT(DISTINCT IDX_CLIENTE) FROM cte_ventas  WHERE fecha = @hoy), 0) AS clientes_atendidos,
            1 AS orden

        UNION ALL

        SELECT
            'SEMANAL',
            ISNULL((SELECT SUM(COSTO_TOTAL)            FROM cte_ventas  WHERE fecha BETWEEN @inicio_semana AND @fin_semana), 0),
            ISNULL((SELECT SUM(utilidad)               FROM cte_ventas  WHERE fecha BETWEEN @inicio_semana AND @fin_semana), 0),
            ISNULL((SELECT SUM(COSTO_TOTAL)            FROM cte_compras WHERE fecha BETWEEN @inicio_semana AND @fin_semana), 0),
            ISNULL((SELECT SUM(VALOR)                  FROM cte_gastos  WHERE fecha BETWEEN @inicio_semana AND @fin_semana), 0),
            ISNULL((SELECT SUM(VALOR_ABONADO)          FROM cte_abonos  WHERE fecha BETWEEN @inicio_semana AND @fin_semana), 0),
            ISNULL((SELECT COUNT(ID_FACTURA)           FROM cte_ventas  WHERE fecha BETWEEN @inicio_semana AND @fin_semana), 0),
            ISNULL((SELECT COUNT(DISTINCT IDX_CLIENTE) FROM cte_ventas  WHERE fecha BETWEEN @inicio_semana AND @fin_semana), 0),
            2

        UNION ALL

        SELECT
            'MENSUAL',
            ISNULL((SELECT SUM(COSTO_TOTAL)            FROM cte_ventas  WHERE fecha BETWEEN @inicio_mes AND @fin_mes), 0),
            ISNULL((SELECT SUM(utilidad)               FROM cte_ventas  WHERE fecha BETWEEN @inicio_mes AND @fin_mes), 0),
            ISNULL((SELECT SUM(COSTO_TOTAL)            FROM cte_compras WHERE fecha BETWEEN @inicio_mes AND @fin_mes), 0),
            ISNULL((SELECT SUM(VALOR)                  FROM cte_gastos  WHERE fecha BETWEEN @inicio_mes AND @fin_mes), 0),
            ISNULL((SELECT SUM(VALOR_ABONADO)          FROM cte_abonos  WHERE fecha BETWEEN @inicio_mes AND @fin_mes), 0),
            ISNULL((SELECT COUNT(ID_FACTURA)           FROM cte_ventas  WHERE fecha BETWEEN @inicio_mes AND @fin_mes), 0),
            ISNULL((SELECT COUNT(DISTINCT IDX_CLIENTE) FROM cte_ventas  WHERE fecha BETWEEN @inicio_mes AND @fin_mes), 0),
            3

    ) AS resultado
    ORDER BY orden;

END
GO


-- ============================================================
-- SP_VENTAS_PRODUCTO_CODIGO
-- Retorna insights de ventas por producto (identificado por
-- CODIGO_BARRAS) para los periodos diario, semanal y mensual.
--
-- Parametro:
--   @codigo_barras  VARCHAR : codigo especifico a consultar.
--                             NULL o '0' = todos los productos.
--
-- Resultado 1 — Una fila por producto con columnas por periodo:
--   diario_cantidad  / diario_ingresos  / diario_utilidad
--   semanal_cantidad / semanal_ingresos / semanal_utilidad
--   mensual_cantidad / mensual_ingresos / mensual_utilidad
--   stock_actual     : unidades disponibles hoy
--   costo_actual     : COSTO_X_UNIDAD vigente
--
-- Nota: la tendencia diaria esta en SP_TENDENCIA_PRODUCTO
-- (llamada separada para evitar CROSS JOIN productos x dias).
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

    -- -------------------------------------------------------
    -- Resultado 1: resumen por producto x periodo
    -- -------------------------------------------------------
    SELECT
        P.PRODUCT_ID                                                    AS producto_id,
        P.CODIGO_BARRAS                                                 AS codigo,
        P.PRODUCTO                                                      AS nombre,
        C.CATEGORIA                                                     AS categoria,
        P.COSTO_X_UNIDAD                                                AS costo_actual,
        P.QUANTITY                                                      AS stock_actual,

        -- DIARIO
        ISNULL(SUM(CASE WHEN CONVERT(DATE, F.FECHA_VENTA) = @hoy
                        THEN VP.QUANTITY       ELSE 0 END), 0)         AS diario_cantidad,
        ISNULL(SUM(CASE WHEN CONVERT(DATE, F.FECHA_VENTA) = @hoy
                        THEN VP.TOTAL_COST     ELSE 0 END), 0)         AS diario_ingresos,
        ISNULL(SUM(CASE WHEN CONVERT(DATE, F.FECHA_VENTA) = @hoy
                        THEN VP.UTILIDAD_TOTAL ELSE 0 END), 0)         AS diario_utilidad,

        -- SEMANAL
        ISNULL(SUM(CASE WHEN CONVERT(DATE, F.FECHA_VENTA)
                             BETWEEN @inicio_semana AND @fin_semana
                        THEN VP.QUANTITY       ELSE 0 END), 0)         AS semanal_cantidad,
        ISNULL(SUM(CASE WHEN CONVERT(DATE, F.FECHA_VENTA)
                             BETWEEN @inicio_semana AND @fin_semana
                        THEN VP.TOTAL_COST     ELSE 0 END), 0)         AS semanal_ingresos,
        ISNULL(SUM(CASE WHEN CONVERT(DATE, F.FECHA_VENTA)
                             BETWEEN @inicio_semana AND @fin_semana
                        THEN VP.UTILIDAD_TOTAL ELSE 0 END), 0)         AS semanal_utilidad,

        -- MENSUAL
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
    INNER JOIN CATEGORIAS C ON P.IDX_CATEGORIA = C.CATEGORIA_ID
    LEFT  JOIN VENDIDO_PRODUCTOS VP ON P.PRODUCT_ID = VP.IDX_PRODUCTO
    LEFT  JOIN FACTURAS F           ON VP.IDX_FACTURA = F.ID_FACTURA

    -- '0' o NULL = todos los productos
    WHERE (@codigo_barras IS NULL OR @codigo_barras = '0' OR P.CODIGO_BARRAS = @codigo_barras)

    GROUP BY
        P.PRODUCT_ID, P.CODIGO_BARRAS, P.PRODUCTO,
        C.CATEGORIA, P.COSTO_X_UNIDAD, P.QUANTITY

    ORDER BY mensual_ingresos DESC;

END
GO


-- ============================================================
-- SP_TENDENCIA_PRODUCTO
-- Retorna la tendencia de ventas diaria del mes en curso para
-- UN producto especifico (identificado por CODIGO_BARRAS).
--
-- Solo devuelve filas donde hubo ventas reales — sin dias vacios,
-- sin CROSS JOIN. El frontend rellena los ceros al graficar.
--
-- Parametro (requerido, no acepta NULL ni '0'):
--   @codigo_barras  VARCHAR : codigo de barras del producto
--
-- Resultado — Una fila por dia con venta registrada:
--   fecha            : fecha del dia
--   producto_id      : PK del producto
--   codigo           : CODIGO_BARRAS
--   nombre           : PRODUCTO
--   cantidad_vendida : unidades vendidas ese dia
--   ingresos         : suma de TOTAL_COST ese dia
--   utilidad         : suma de UTILIDAD_TOTAL ese dia
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

  select * from PRODUCTOS

    DECLARE @inicio_mes DATE = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
    DECLARE @fin_mes    DATE = EOMONTH(GETDATE());

    -- Solo dias con ventas reales del producto en el mes actual
    SELECT
        CONVERT(DATE, F.FECHA_VENTA)    AS fecha,
        P.PRODUCT_ID                    AS producto_id,
        P.CODIGO_BARRAS                 AS codigo,
        P.PRODUCTO                      AS nombre,
        SUM(VP.QUANTITY)                AS cantidad_vendida,
        SUM(VP.TOTAL_COST)              AS ingresos,
        SUM(VP.UTILIDAD_TOTAL)          AS utilidad

    FROM VENDIDO_PRODUCTOS VP
    INNER JOIN FACTURAS  F ON VP.IDX_FACTURA = F.ID_FACTURA
    INNER JOIN PRODUCTOS P ON VP.IDX_PRODUCTO = P.PRODUCT_ID

    WHERE (@codigo_barras = '0' or P.CODIGO_BARRAS = @codigo_barras)
      AND CONVERT(DATE, F.FECHA_VENTA) BETWEEN @inicio_mes AND @fin_mes

    GROUP BY CONVERT(DATE, F.FECHA_VENTA), P.PRODUCT_ID, P.CODIGO_BARRAS, P.PRODUCTO

    ORDER BY fecha;

END
GO


-- ============================================================
-- SP_LISTADO_PERIODOS
-- Retorna el listado real de FACTURAS y COMPRAS para un
-- periodo dado: DIARIO, SEMANAL o MENSUAL.
--
-- Parametro:
--   @periodo  VARCHAR : 'DIARIO' | 'SEMANAL' | 'MENSUAL'
--
-- Resultado 1 — Facturas del periodo (una fila por factura)
-- Resultado 2 — Compras del periodo  (una fila por compra)
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

    -- Rango activo segun periodo
    DECLARE @f_ini DATE, @f_fin DATE;

    IF @periodo = 'DIARIO'
    BEGIN
        SET @f_ini = @hoy;
        SET @f_fin = @hoy;
    END
    ELSE IF @periodo = 'SEMANAL'
    BEGIN
        SET @f_ini = @inicio_semana;
        SET @f_fin = @fin_semana;
    END
    ELSE IF @periodo = 'MENSUAL'
    BEGIN
        SET @f_ini = @inicio_mes;
        SET @f_fin = @fin_mes;
    END
    ELSE
    BEGIN
        RAISERROR('Periodo invalido. Use: DIARIO, SEMANAL o MENSUAL', 16, 1);
        RETURN;
    END

    -- -------------------------------------------------------
    -- Resultado 1: Facturas del periodo
    -- -------------------------------------------------------
    SELECT
        F.ID_FACTURA                                                AS id_factura,
        FORMAT(F.FECHA_VENTA, 'dd/MM/yyyy HH:mm')                  AS fecha_venta,
        CONCAT(CL.NOMBRES, ' ', CL.APELLIDOS)                      AS cliente,
        CL.NUMERO_TELEFONO                                          AS telefono_cliente,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                      AS vendedor,
        FP.FORMA_PAGO                                               AS forma_pago,
        F.COSTO_TOTAL                                               AS total,
        F.VALOR_PAGADO                                              AS pagado,
        F.COSTO_TOTAL - F.VALOR_PAGADO                             AS pendiente,
        F.VALOR_IVA                                                 AS valor_iva,
        F.CONSUMIDOR_FINAL                                          AS consumidor_final,
        ISNULL(UP.utilidad_factura, 0)                             AS utilidad_total

    FROM FACTURAS F
    INNER JOIN CLIENTES         CL ON F.IDX_CLIENTE  = CL.CLIENTE_ID
    INNER JOIN USUARIOS         US ON F.IDX_USUARIO  = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES DP ON US.IDX_DATOS_PERSONALES = DP.DATOS_PERSONALES_ID
    INNER JOIN FORMAS_PAGO      FP ON F.IDX_FORMA_PAGO = FP.ID_FORMA_PAGO
    LEFT JOIN (
        SELECT IDX_FACTURA, SUM(UTILIDAD_TOTAL) AS utilidad_factura
        FROM VENDIDO_PRODUCTOS
        GROUP BY IDX_FACTURA
    ) UP ON F.ID_FACTURA = UP.IDX_FACTURA

    WHERE CONVERT(DATE, F.FECHA_VENTA) BETWEEN @f_ini AND @f_fin

    ORDER BY F.FECHA_VENTA DESC;

    -- -------------------------------------------------------
    -- Resultado 2: Compras del periodo
    -- -------------------------------------------------------
    SELECT
        C.ID_COMPRA                                                 AS id_compra,
        FORMAT(C.FECHA_COMPRA, 'dd/MM/yyyy HH:mm')                 AS fecha_compra,
        PV.RAZON_SOCIAL                                             AS proveedor,
        PV.TELEFONO                                                 AS telefono_proveedor,
        CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS)                      AS comprador,
        FP.FORMA_PAGO                                               AS forma_pago,
        C.COSTO_TOTAL                                               AS total,
        C.VALOR_PAGADO                                              AS pagado,
        C.COSTO_TOTAL - C.VALOR_PAGADO                             AS pendiente,
        C.PAGO_INICIAL                                             AS pago_inicial

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
-- SP_RADAR_STOCK
-- Analiza la velocidad de ventas de cada producto en los
-- ultimos 30 dias y proyecta cuantos dias de stock quedan.
--
-- Sin parametros — retorna todos los productos activos.
--
-- Columnas retornadas:
--   producto_id        : PK del producto
--   codigo             : CODIGO_BARRAS
--   nombre             : PRODUCTO
--   categoria          : nombre de categoria
--   stock_actual       : unidades actuales en inventario
--   costo_actual       : COSTO_X_UNIDAD vigente
--   vendido_30_dias    : unidades vendidas en los ultimos 30 dias
--   velocidad_diaria   : promedio de unidades vendidas por dia
--   dias_hasta_agotarse: proyeccion de dias de stock restante
--   estado             : AGOTADO | CRITICO | ALERTA | OK | SIN_MOVIMIENTO
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
        -- Unidades vendidas por producto en los ultimos 30 dias
        SELECT VP.IDX_PRODUCTO, SUM(VP.QUANTITY) AS total_vendido
        FROM VENDIDO_PRODUCTOS VP
        INNER JOIN FACTURAS F ON VP.IDX_FACTURA = F.ID_FACTURA
        WHERE CONVERT(DATE, F.FECHA_VENTA) BETWEEN @hace30 AND @hoy
        GROUP BY VP.IDX_PRODUCTO
    ),
    cte_base AS (
        SELECT
            P.PRODUCT_ID,
            P.CODIGO_BARRAS,
            P.PRODUCTO,
            C.CATEGORIA,
            P.QUANTITY                                                  AS stock_actual,
            P.COSTO_X_UNIDAD                                            AS costo_actual,
            ISNULL(V.total_vendido, 0)                                  AS vendido_30_dias,
            CAST(ISNULL(V.total_vendido, 0) / 30.0 AS DECIMAL(10,2))   AS velocidad_diaria,
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
        PRODUCT_ID                                  AS producto_id,
        CODIGO_BARRAS                               AS codigo,
        PRODUCTO                                    AS nombre,
        CATEGORIA                                   AS categoria,
        stock_actual,
        costo_actual,
        vendido_30_dias,
        velocidad_diaria,
        dias_hasta_agotarse,
        CASE
            WHEN stock_actual = 0                                   THEN 'AGOTADO'
            WHEN vendido_30_dias = 0                                THEN 'SIN_MOVIMIENTO'
            WHEN dias_hasta_agotarse < 7                            THEN 'CRITICO'
            WHEN dias_hasta_agotarse < 20                           THEN 'ALERTA'
            ELSE 'OK'
        END AS estado
    FROM cte_base
    ORDER BY
        -- Urgencia primero: agotados > criticos > alertas > ok > sin movimiento
        CASE
            WHEN stock_actual = 0                                   THEN 1
            WHEN vendido_30_dias > 0 AND dias_hasta_agotarse < 7   THEN 2
            WHEN vendido_30_dias > 0 AND dias_hasta_agotarse < 20  THEN 3
            WHEN vendido_30_dias > 0                                THEN 4
            ELSE 5
        END,
        dias_hasta_agotarse ASC;    -- NULLs (SIN_MOVIMIENTO) van al final automaticamente

END
GO


-- ============================================================
-- SP_CARTERA_CLIENTES
-- Snapshot completo de cuentas por cobrar: clientes con deuda
-- pendiente, cuanto deben, cuando fue su ultimo pago y estado
-- de riesgo.
--
-- Sin parametros — retorna solo clientes con SALDO_NEGATIVO > 0
--
-- Columnas retornadas:
--   cliente_id          : PK del cliente
--   cliente             : nombre completo
--   telefono            : numero de contacto
--   deuda_total         : SALDO_NEGATIVO actual
--   saldo_favor         : SALDO a favor (creditos)
--   facturas_pendientes : facturas con pago incompleto
--   total_abonado       : suma historica de abonos recibidos
--   ultimo_pago         : fecha del ultimo abono registrado
--   dias_sin_pagar      : dias transcurridos desde el ultimo abono
--   estado              : AL_DIA | NORMAL | RIESGO | EN_MORA | SIN_ABONOS
-- ============================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER   PROCEDURE [dbo].[SP_CARTERA_CLIENTES]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        CL.CLIENTE_ID                                               AS cliente_id,
        CONCAT(CL.NOMBRES, ' ', CL.APELLIDOS)                      AS cliente,
        CL.NUMERO_TELEFONO                                          AS telefono,
        CL.SALDO_NEGATIVO                                           AS deuda_total,
        CL.SALDO                                                    AS saldo_favor,

        ISNULL(FP.facturas_pendientes, 0)                          AS facturas_pendientes,
        ISNULL(AB.total_abonado, 0)                                AS total_abonado,
        AB.ultimo_pago,

        -- Dias transcurridos desde el ultimo abono
        CASE
            WHEN AB.ultimo_pago IS NULL THEN NULL
            ELSE DATEDIFF(DAY, AB.ultimo_pago, GETDATE())
        END AS dias_sin_pagar,

        -- Estado de riesgo
        CASE
            WHEN AB.ultimo_pago IS NULL                                       THEN 'SIN_ABONOS'
            WHEN DATEDIFF(DAY, AB.ultimo_pago, GETDATE()) > 30               THEN 'EN_MORA'
            WHEN DATEDIFF(DAY, AB.ultimo_pago, GETDATE()) > 15               THEN 'RIESGO'
            ELSE 'NORMAL'
        END AS estado

    FROM CLIENTES CL

    -- Facturas con pago incompleto
    LEFT JOIN (
        SELECT IDX_CLIENTE, COUNT(ID_FACTURA) AS facturas_pendientes
        FROM FACTURAS
        WHERE IDX_FORMA_PAGO = 2 AND COSTO_TOTAL > VALOR_PAGADO
        GROUP BY IDX_CLIENTE
    ) FP ON CL.CLIENTE_ID = FP.IDX_CLIENTE

    -- Historial de abonos del cliente
    LEFT JOIN (
        SELECT IDX_CLIENTE,
               SUM(VALOR_ABONADO)  AS total_abonado,
               MAX(FECHA_ABONO)    AS ultimo_pago
        FROM DETALLE_ABONOS_VENTAS
        GROUP BY IDX_CLIENTE
    ) AB ON CL.CLIENTE_ID = AB.IDX_CLIENTE

    WHERE CL.SALDO_NEGATIVO > 0

    ORDER BY
        -- Mora primero, luego por monto de deuda
        CASE
            WHEN AB.ultimo_pago IS NULL                             THEN 1
            WHEN DATEDIFF(DAY, AB.ultimo_pago, GETDATE()) > 30     THEN 2
            WHEN DATEDIFF(DAY, AB.ultimo_pago, GETDATE()) > 15     THEN 3
            ELSE 4
        END,
        CL.SALDO_NEGATIVO DESC;

END



-- ============================================================
-- SP_MARGEN_REAL
-- Calcula el margen real de cada producto basado en la utilidad
-- congelada al momento de cada venta (UTILIDAD_TOTAL en
-- VENDIDO_PRODUCTOS), comparada contra el costo actual.
--
-- Sin parametros — retorna todos los productos activos.
--
-- Columnas retornadas:
--   producto_id          : PK del producto
--   codigo               : CODIGO_BARRAS
--   nombre               : PRODUCTO
--   categoria            : nombre de categoria
--   costo_actual         : COSTO_X_UNIDAD vigente hoy
--   unidades_vendidas    : total historico de unidades vendidas
--   ingresos_totales     : suma historica de TOTAL_COST
--   utilidad_total       : suma historica de UTILIDAD_TOTAL
--   precio_prom_venta    : ingreso promedio por unidad vendida
--   costo_prom_vendido   : costo promedio unitario al momento de vender
--   margen_pct           : utilidad_total / ingresos_totales * 100
--   estado_margen        : OK | MARGEN_BAJO | MARGEN_CRITICO | SIN_VENTAS
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
            IDX_PRODUCTO,
            SUM(QUANTITY)       AS unidades_vendidas,
            SUM(TOTAL_COST)     AS ingresos_totales,
            SUM(UTILIDAD_TOTAL) AS utilidad_total
        FROM VENDIDO_PRODUCTOS
        GROUP BY IDX_PRODUCTO
    )
    SELECT
        P.PRODUCT_ID                                                AS producto_id,
        P.CODIGO_BARRAS                                             AS codigo,
        P.PRODUCTO                                                  AS nombre,
        C.CATEGORIA                                                 AS categoria,
        P.COSTO_X_UNIDAD                                            AS costo_actual,

        ISNULL(V.unidades_vendidas, 0)                             AS unidades_vendidas,
        ISNULL(V.ingresos_totales,  0)                             AS ingresos_totales,
        ISNULL(V.utilidad_total,    0)                             AS utilidad_total,

        -- Precio promedio de venta por unidad
        CASE
            WHEN ISNULL(V.unidades_vendidas, 0) = 0 THEN 0
            ELSE CAST(V.ingresos_totales / V.unidades_vendidas AS DECIMAL(18,2))
        END AS precio_prom_venta,

        -- Costo promedio al momento de vender (precio - utilidad / unidades)
        CASE
            WHEN ISNULL(V.unidades_vendidas, 0) = 0 THEN P.COSTO_X_UNIDAD
            ELSE CAST((V.ingresos_totales - V.utilidad_total) / V.unidades_vendidas AS DECIMAL(18,2))
        END AS costo_prom_vendido,

        -- Margen porcentual (utilidad / ingresos)
        CASE
            WHEN ISNULL(V.ingresos_totales, 0) = 0 THEN 0
            ELSE CAST(V.utilidad_total / V.ingresos_totales * 100 AS DECIMAL(5,2))
        END AS margen_pct,

        -- Estado del margen
        CASE
            WHEN ISNULL(V.unidades_vendidas, 0) = 0              THEN 'SIN_VENTAS'
            WHEN V.utilidad_total / NULLIF(V.ingresos_totales, 0) * 100 < 5  THEN 'MARGEN_CRITICO'
            WHEN V.utilidad_total / NULLIF(V.ingresos_totales, 0) * 100 < 15 THEN 'MARGEN_BAJO'
            ELSE 'OK'
        END AS estado_margen

    FROM PRODUCTOS P
    INNER JOIN CATEGORIAS C ON P.IDX_CATEGORIA = C.CATEGORIA_ID
    LEFT  JOIN cte_ventas V ON P.PRODUCT_ID = V.IDX_PRODUCTO
    WHERE P.ESTADOS = 1

    ORDER BY
        -- Criticos y bajos primero, luego por mayor ingreso generado
        CASE
            WHEN ISNULL(V.unidades_vendidas, 0) = 0                                            THEN 4
            WHEN V.utilidad_total / NULLIF(V.ingresos_totales, 0) * 100 < 5                   THEN 1
            WHEN V.utilidad_total / NULLIF(V.ingresos_totales, 0) * 100 < 15                  THEN 2
            ELSE 3
        END,
        ISNULL(V.ingresos_totales, 0) DESC;

END
GO
