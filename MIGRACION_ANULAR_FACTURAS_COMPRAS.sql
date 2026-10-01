-- =====================================================================================
-- MIGRACION: Anular Facturas y Compras (sin eliminar, solo cambio de estado)
-- Ejecutar completo, en orden, contra la base de datos de MOTO_MASTERS.
-- Es re-ejecutable: las ALTER TABLE se protegen con COL_LENGTH, y todos los
-- procedimientos usan CREATE OR ALTER.
-- =====================================================================================

-- =====================================================================================
-- 1. ESQUEMA
-- =====================================================================================

IF COL_LENGTH('dbo.FACTURAS', 'ANULADO_FECHA') IS NULL
    ALTER TABLE dbo.FACTURAS ADD ANULADO_FECHA DATETIME NULL;
GO
IF COL_LENGTH('dbo.FACTURAS', 'ANULADO_POR') IS NULL
    ALTER TABLE dbo.FACTURAS ADD ANULADO_POR NUMERIC(18,0) NULL;
GO

IF COL_LENGTH('dbo.COMPRAS', 'ANULADO') IS NULL
    ALTER TABLE dbo.COMPRAS ADD ANULADO BIT NULL CONSTRAINT DF_COMPRAS_ANULADO DEFAULT (0);
GO
IF COL_LENGTH('dbo.COMPRAS', 'ANULADO_FECHA') IS NULL
    ALTER TABLE dbo.COMPRAS ADD ANULADO_FECHA DATETIME NULL;
GO
IF COL_LENGTH('dbo.COMPRAS', 'ANULADO_POR') IS NULL
    ALTER TABLE dbo.COMPRAS ADD ANULADO_POR NUMERIC(18,0) NULL;
GO

-- IMPORTANTE: a diferencia de FACTURAS (donde "Forma de pago" SI incluye la
-- opcion "Credito" = IDX_FORMA_PAGO 2 como parte del mismo dropdown), en el
-- formulario de Comprar el checkbox "Pago a credito" es un campo INDEPENDIENTE
-- del dropdown "Forma de pago" (que solo guarda Efectivo/Banco/etc). Por lo
-- tanto IDX_FORMA_PAGO en COMPRAS nunca fue una senal confiable de credito.
-- Se agrega una columna persistida propia para saber, de forma confiable,
-- si una compra fue a credito (usada por InsertarCompraMasiva, SP_ANULAR_COMPRA
-- y SP_ABONOS_COMPRAS).
IF COL_LENGTH('dbo.COMPRAS', 'CREDITO') IS NULL
    ALTER TABLE dbo.COMPRAS ADD CREDITO BIT NULL CONSTRAINT DF_COMPRAS_CREDITO DEFAULT (0);
GO

-- =====================================================================================
-- 2. SP_FACTURAS_ACCIONES — completar rama 'anularFactura' (idempotencia + auditoria)
--    El resto de las ramas (crearFactura, venderProducto, venderServicio,
--    actualizarTotalIva) se dejan intactas.
-- =====================================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[SP_FACTURAS_ACCIONES]
	@accion							VARCHAR(100),
	@id_factura						NUMERIC(18,0) = NULL,
	@idx_cliente					NUMERIC(18,0) = NULL,
	@idx_usuario					NUMERIC(18,0) = NULL,
	@costo_total					NUMERIC(18,2) = NULL,
	@estado							BIT           = NULL,
	@consumidor_final				BIT           = NULL,
	@cufe_factura					VARCHAR(1000) = NULL,
	@idx_producto					NUMERIC(18,0) = NULL,
	@cantidad						NUMERIC(18,2) = NULL,
	@forma_pago						NUMERIC(18,0) = NULL,
	@forma_pago_inicial				NUMERIC(18,0) = 0,
	@pago_inicial					NUMERIC(18,2) = NULL,
	@usa_saldo_favor				BIT           = NULL,
	@gramaje_total					NUMERIC(18,2) = NULL,
	@idx_servicio					NUMERIC(18,0) = NULL,
	@cliente_dejo_llaves			BIT           = NULL,
	@descripcion_llaves				VARCHAR(100)  = NULL,
	@bit_vehiculo_inicial			BIT           = NULL,
	@placa_vehiculo					VARCHAR(15)   = NULL,
	@color_vehiculo					VARCHAR(100)  = NULL,
	@marca_vehiculo					VARCHAR(15)   = NULL,
	@costo_adicional				FLOAT         = NULL
AS
BEGIN
	DECLARE @porcentaje_iva NUMERIC(18,2) =
		ISNULL((SELECT TOP 1 PORCENTAJE_IVA FROM CONFIGURACIONES), 0);

	-- -------------------------------------------------------------
	IF (@accion = 'crearFactura')
	BEGIN
		DECLARE @saldo_favor       DECIMAL(18,2);
		DECLARE @saldo_negativo    DECIMAL(18,2);
		DECLARE @caja              NUMERIC(18,0) =
			(SELECT TOP 1 ID_CAJA FROM CAJA
			  WHERE IDX_USUARIO = @idx_usuario AND FECHA_CIERRE_CAJA IS NULL);

		SELECT @saldo_favor      = SALDO,
		       @saldo_negativo   = SALDO_NEGATIVO
		FROM CLIENTES WHERE CLIENTE_ID = @idx_cliente;

		IF (@usa_saldo_favor = 1)
		BEGIN
			DECLARE @disponible DECIMAL(18,2) = @saldo_favor;
			IF (@disponible >= @costo_total)
			BEGIN
				SET @pago_inicial      = @costo_total;
				SET @saldo_favor       = @disponible - @costo_total;
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
			IF (@pago_inicial < @costo_total AND @forma_pago = 2)
				SET @saldo_negativo = @saldo_negativo + (@costo_total - @pago_inicial);
		END

		UPDATE CLIENTES SET
			SALDO            = @saldo_favor,
			SALDO_NEGATIVO   = @saldo_negativo
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

		-- Asignar numero DIAN de la resolucion activa (atomico)
		DECLARE @resolucion TABLE (
			numero_dian           NUMERIC(18,0),
			prefijo               VARCHAR(10),
			numero_resolucion     VARCHAR(20),
			fecha_resolucion      DATE,
			fecha_inicio          DATE,
			fecha_fin             DATE,
			rango_inicio          NUMERIC(18,0),
			rango_fin             NUMERIC(18,0),
			clave_tecnica         VARCHAR(200)
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
		    AND TIPO       = 'FC'
		    AND CAST(GETDATE() AS DATE) BETWEEN FECHA_INICIO_VIGENCIA AND FECHA_FIN_VIGENCIA
		    AND NUMERO_ACTUAL < RANGO_FIN;

		-- Si existe resolucion activa, guardar numero DIAN y marcar PENDIENTE
		IF EXISTS (SELECT 1 FROM @resolucion)
			UPDATE FACTURAS SET
				NUMERO_FACTURA_DIAN = (SELECT numero_dian FROM @resolucion),
				ESTADO_DIAN         = 'PENDIENTE'
			WHERE ID_FACTURA = @NuevoID;

		SELECT @NuevoID AS ID_INSERTADO;
	END

	-- -------------------------------------------------------------
	ELSE IF (@accion = 'venderProducto')
	BEGIN
		DECLARE @COSTO_UNITARIO_AL_VENDER      DECIMAL(18,2) =
			(SELECT COSTO_X_UNIDAD FROM PRODUCTOS WHERE PRODUCT_ID = @idx_producto);
		DECLARE @PRECIO_UNITARIO_VENTA            DECIMAL(18,2) = @costo_total / @cantidad;
		DECLARE @UTILIDAD_UNITARIA                DECIMAL(18,2) =
			@PRECIO_UNITARIO_VENTA - @COSTO_UNITARIO_AL_VENDER;
		DECLARE @UTILIDAD_TOTAL                   DECIMAL(18,2) = @UTILIDAD_UNITARIA * @cantidad;
		DECLARE @gramaje_total_producto            NUMERIC(18,2) =
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
			QUANTITY                     = QUANTITY - @cantidad,
			GRAMAJE_DEL_PRODUCTO         = ISNULL(@gramaje_total_producto, 0) - ISNULL(@gramaje_total, 0)
		WHERE PRODUCT_ID = @idx_producto;
	END

	-- -------------------------------------------------------------
	ELSE IF (@accion = 'venderServicio')
	BEGIN
		-- El precio (@costo_total) es el valor ingresado manualmente
		-- en Vender; no se recalcula contra COSTO_REGULAR de SERVICIOS.
		INSERT INTO SERVICIOS_DADOS (
			IDX_FACTURA, IDX_SERVICIO, CLIENTE_DEJO_LLAVES, DESCRIPCION_LLAVES,
			BIT_VEHICULO_INICIAL, PLACA_VEHICULO, COLOR_VEHICULO, MARCA_VEHICULO,
			COSTO_ADICIONAL, TOTAL_COST, FECHA_SERVICIO_DADO, VALOR_IVA, SUB_TOTAL
		)
		VALUES (
			@id_factura, @idx_servicio, ISNULL(@cliente_dejo_llaves, 0), @descripcion_llaves,
			@bit_vehiculo_inicial, @placa_vehiculo, @color_vehiculo, @marca_vehiculo,
			@costo_adicional, @costo_total, GETDATE(),
			(@costo_total * @porcentaje_iva),
			@costo_total - (@costo_total * @porcentaje_iva)
		);
	END

	-- -------------------------------------------------------------
	ELSE IF (@accion = 'actualizarTotalIva')
	BEGIN
		UPDATE FACTURAS SET
			VALOR_IVA = ISNULL((SELECT SUM(VALOR_IVA) FROM VENDIDO_PRODUCTOS WHERE IDX_FACTURA = @id_factura), 0)
			          + ISNULL((SELECT SUM(VALOR_IVA) FROM SERVICIOS_DADOS   WHERE IDX_FACTURA = @id_factura), 0)
		WHERE ID_FACTURA = @id_factura;
	END

	-- -------------------------------------------------------------
	ELSE IF (@accion = 'anularFactura')
	BEGIN
		-- Idempotencia: no reprocesar una factura ya anulada
		IF EXISTS (SELECT 1 FROM FACTURAS WHERE ID_FACTURA = @id_factura AND ANULADO = 1)
		BEGIN
			RAISERROR('La factura ya se encuentra anulada.', 16, 1);
			RETURN;
		END

		-- 1. Marcar factura como anulada (auditoria: quien y cuando)
		UPDATE FACTURAS SET
			ANULADO       = 1,
			ESTADO_DIAN   = 'ANULADA',
			ANULADO_FECHA = GETDATE(),
			ANULADO_POR   = @idx_usuario
		WHERE ID_FACTURA = @id_factura;

		-- 2. Restaurar stock (QUANTITY + GRAMAJE, exactamente inverso a venderProducto)
		UPDATE P SET
			P.QUANTITY                   = P.QUANTITY + VP.QUANTITY,
			P.GRAMAJE_DEL_PRODUCTO       = P.GRAMAJE_DEL_PRODUCTO + ISNULL(VP.GRAMAJE_VENDIDO, 0)
		FROM PRODUCTOS P
		INNER JOIN VENDIDO_PRODUCTOS VP ON P.PRODUCT_ID = VP.IDX_PRODUCTO
		WHERE VP.IDX_FACTURA = @id_factura;

		-- 3. Revertir saldo del cliente (solo facturas a credito IDX_FORMA_PAGO = 2)
		--    Deja la deuda atribuible a esta factura en 0, sin importar los abonos
		--    ya realizados (VALOR_PAGADO ya refleja el efecto neto de esos abonos).
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
		-- NOTA: VALOR_PAGADO (dinero fisico ya recibido) NO se acredita automaticamente.
		-- La devolucion en efectivo debe registrarse como movimiento de caja manual.
	END
END
GO

-- =====================================================================================
-- 3. SP_ANULAR_COMPRA — nueva SP dedicada, espejo de SP_FACTURAS_ACCIONES/'anularFactura'
-- =====================================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[SP_ANULAR_COMPRA]
    @id_compra   NUMERIC(18,0),
    @idx_usuario NUMERIC(18,0) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Idempotencia: no reprocesar una compra ya anulada
    IF EXISTS (SELECT 1 FROM COMPRAS WHERE ID_COMPRA = @id_compra AND ANULADO = 1)
    BEGIN
        RAISERROR('La compra ya se encuentra anulada.', 16, 1);
        RETURN;
    END

    -- 1. Marcar compra como anulada (auditoria: quien y cuando)
    UPDATE COMPRAS SET
        ANULADO       = 1,
        ANULADO_FECHA = GETDATE(),
        ANULADO_POR   = @idx_usuario
    WHERE ID_COMPRA = @id_compra;

    -- 2. Revertir stock/gramaje (exactamente inverso a InsertarCompraMasiva).
    --    Se permite que quede negativo si el producto ya fue vendido: es una
    --    senal para revisar manualmente (aparecera en el radar de stock).
    UPDATE P SET
        P.QUANTITY             = P.QUANTITY - CD.CANTIDAD,
        P.GRAMAJE_DEL_PRODUCTO = ISNULL(P.GRAMAJE_DEL_PRODUCTO, 0) - ISNULL(CD.GRAMAJE_COMPRADO, 0)
    FROM PRODUCTOS P
    INNER JOIN COMPRAS_DETALLES CD ON P.PRODUCT_ID = CD.IDX_PRODUCTO
    WHERE CD.IDX_COMPRA = @id_compra;

    -- 3. Revertir deuda al proveedor (solo compras a credito, CREDITO = 1).
    --    Deja la deuda atribuible a esta compra en 0, sin importar los abonos
    --    ya realizados (VALOR_PAGADO ya refleja el efecto neto de esos abonos).
    --    NOTA: se usa CREDITO (columna persistida) y NO IDX_FORMA_PAGO, porque
    --    en Comprar el checkbox "Pago a credito" es independiente del dropdown
    --    "Forma de pago" — IDX_FORMA_PAGO no indica de forma confiable si fue credito.
    UPDATE PROVEEDORES SET
        SALDO_PENDIENTE = SALDO_PENDIENTE -
            ISNULL((
                SELECT CASE WHEN CREDITO = 1
                            THEN COSTO_TOTAL - ISNULL(VALOR_PAGADO, 0)
                            ELSE 0
                       END
                FROM COMPRAS WHERE ID_COMPRA = @id_compra
            ), 0)
    WHERE ID_PROVEEDOR = (SELECT IDX_PROVEEDOR FROM COMPRAS WHERE ID_COMPRA = @id_compra);
    -- NOTA: VALOR_PAGADO (dinero fisico ya entregado) NO se acredita automaticamente.
    -- La devolucion de dinero debe registrarse como movimiento de caja manual.
END
GO

-- =====================================================================================
-- 4. CAJA_ACCIONES — excluir documentos anulados del cuadre/cierre de caja.
--    (Hallazgo critico: hoy no filtra ANULADO en absoluto, ni para FACTURAS
--    que ya tenian la columna.)
-- =====================================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[CAJA_ACCIONES]
    @OPERACION VARCHAR(100),
    @ID_CAJA NUMERIC(18,0) = NULL OUTPUT,
    @ID_USUARIO NUMERIC(18,0),
    @cuerpoSaldosCaja CuerpoSaldosCajaTVP READONLY
AS
BEGIN
    SET NOCOUNT ON;

    IF @OPERACION = 'ABRIR_CAJA'
    BEGIN
        DECLARE @FECHA_ABRIR DATETIME = GETDATE();

        -- Insertar caja
        INSERT INTO CAJA (IDX_USUARIO, FECHA_APERTURA_CAJA, SALDO_APERTURA)
        SELECT TOP 1 @ID_USUARIO, @FECHA_ABRIR, SUM(SALDO)
        FROM @cuerpoSaldosCaja;

        -- Obtener el ID generado
        SET @ID_CAJA = SCOPE_IDENTITY();

        -- Insertar los saldos de apertura
        INSERT INTO SALDOS_APERTURA_CAJA (IDX_CAJA, IDX_DENOMINACION, SALDO)
        SELECT @ID_CAJA, IDX_DENOMINACION, SALDO
        FROM @cuerpoSaldosCaja;
    END

    ELSE IF @OPERACION = 'CERRAR_CAJA'
    BEGIN
        DECLARE @FECHA_CERRAR DATETIME = GETDATE();
		SET @ID_CAJA = (SELECT TOP 1 ID_CAJA FROM CAJA WHERE IDX_USUARIO = @ID_USUARIO AND FECHA_CIERRE_CAJA IS NULL);

DECLARE @TOTAL_CIERRE NUMERIC(18,2) = (SELECT
  (
    -- Ingresos (excluye facturas/abonos de documentos anulados)
    ISNULL((SELECT SUM(COSTO_TOTAL) FROM FACTURAS WHERE IDX_CAJA = @ID_CAJA AND IDX_FORMA_PAGO <> 2 AND (ANULADO IS NULL OR ANULADO <> 1)), 0) +
    ISNULL((SELECT SUM(PAGO_INICIAL) FROM FACTURAS WHERE IDX_CAJA = @ID_CAJA AND IDX_FORMA_PAGO = 2 AND (ANULADO IS NULL OR ANULADO <> 1)), 0) +
    ISNULL((SELECT SUM(VALOR_ABONADO) FROM DETALLE_ABONOS_VENTAS WHERE IDX_CAJA = @ID_CAJA AND IDX_FORMA_PAGO <> 2 AND IDX_FACTURA IN (SELECT ID_FACTURA FROM FACTURAS WHERE ANULADO IS NULL OR ANULADO <> 1)), 0) +
	ISNULL((SELECT SUM(SALDO) FROM SALDOS_APERTURA_CAJA WHERE IDX_CAJA = @ID_CAJA),0) +
	ISNULL((SELECT SUM(VALOR) FROM MOVIMIENTOS_CAJA WHERE IDX_CAJA = @ID_CAJA AND IDX_TIPO_MOVIMIENTO = 1),0)
  )
  -
  (
    -- Egresos (excluye compras/abonos de documentos anulados).
    -- NOTA: para COMPRAS se usa CREDITO (no IDX_FORMA_PAGO) porque el checkbox
    -- "Pago a credito" es independiente del dropdown "Forma de pago".
    ISNULL((SELECT SUM(COSTO_TOTAL) FROM COMPRAS WHERE IDX_CAJA = @ID_CAJA AND (CREDITO IS NULL OR CREDITO <> 1) AND (ANULADO IS NULL OR ANULADO <> 1)), 0) +
    ISNULL((SELECT SUM(PAGO_INICIAL) FROM COMPRAS WHERE IDX_CAJA = @ID_CAJA AND CREDITO = 1 AND (ANULADO IS NULL OR ANULADO <> 1)), 0) +
    ISNULL((SELECT SUM(VALOR_ABONADO) FROM DETALLE_ABONOS_COMPRAS WHERE IDX_CAJA = @ID_CAJA AND IDX_FORMA_PAGO <> 2 AND IDX_COMPRA IN (SELECT ID_COMPRA FROM COMPRAS WHERE ANULADO IS NULL OR ANULADO <> 1)), 0) +
	ISNULL((SELECT SUM(VALOR) FROM MOVIMIENTOS_CAJA WHERE IDX_CAJA = @ID_CAJA AND IDX_TIPO_MOVIMIENTO = 2),0)
  ))

        -- Actualizar la caja con cierre
        UPDATE CAJA
        SET FECHA_CIERRE_CAJA = @FECHA_CERRAR,
            SALDO_CIERRE = @TOTAL_CIERRE
        WHERE ID_CAJA = @ID_CAJA;

        INSERT INTO SALDOS_CIERRE_CAJA (IDX_CAJA, IDX_DENOMINACION, SALDO)
        SELECT @ID_CAJA, IDX_DENOMINACION, SALDO
        FROM @cuerpoSaldosCaja;
    END

	ELSE IF @OPERACION = 'ESTADO_CAJA'
    BEGIN
        SELECT CASE (SELECT COUNT(ID_CAJA) FROM CAJA WHERE IDX_USUARIO = @ID_USUARIO AND FECHA_CIERRE_CAJA IS NULL) WHEN 0 THEN 0 ELSE 1 END AS estado
    END

	ELSE IF @OPERACION = 'VERIFICACION'
	BEGIN

	DECLARE @caja numeric(18,0) = (SELECT TOP 1 ID_CAJA FROM CAJA WHERE IDX_USUARIO = @ID_USUARIO AND FECHA_CIERRE_CAJA IS NULL)
	IF @ID_CAJA IS NOT NULL
		BEGIN
			SET @caja = @ID_CAJA
		END

	--Dinero recibido o de salida (excluye facturas/compras anuladas)
	SELECT COUNT(ID_FACTURA) AS facturas_creadas, SUM(ISNULL(COSTO_TOTAL,0))  + ISNULL((SELECT SUM(PAGO_INICIAL) FROM FACTURAS WHERE IDX_FORMA_PAGO = 2 AND IDX_CAJA = @caja AND (ANULADO IS NULL OR ANULADO <> 1)),0) AS 'dinero_por_facturas' FROM FACTURAS WHERE IDX_CAJA = @caja AND IDX_FORMA_PAGO <> 2 AND (ANULADO IS NULL OR ANULADO <> 1)

	SELECT ISNULL(COUNT(ID_COMPRA),0) + ISNULL((SELECT ISNULL(COUNT(ID_COMPRA),0) FROM COMPRAS WHERE IDX_CAJA = @caja AND CREDITO = 1 AND (ANULADO IS NULL OR ANULADO <> 1)),0) AS compras_hechas, (SELECT ISNULL(SUM(PAGO_INICIAL),0) FROM COMPRAS WHERE CREDITO = 1 AND IDX_CAJA = @caja AND (ANULADO IS NULL OR ANULADO <> 1)) + (SELECT ISNULL(SUM(VALOR_PAGADO),0) FROM COMPRAS WHERE (CREDITO IS NULL OR CREDITO <> 1) AND IDX_CAJA = @caja AND (ANULADO IS NULL OR ANULADO <> 1)) AS dinero_gastado_en_compras FROM COMPRAS WHERE IDX_CAJA = @caja AND (CREDITO IS NULL OR CREDITO <> 1) AND (ANULADO IS NULL OR ANULADO <> 1)

	SELECT COUNT(ID_DETALLE) AS abonos_recibidos, SUM(VALOR_ABONADO) AS total_por_abonos FROM DETALLE_ABONOS_VENTAS WHERE IDX_FORMA_PAGO <> 2 AND IDX_CAJA = @caja AND IDX_FACTURA IN (SELECT ID_FACTURA FROM FACTURAS WHERE ANULADO IS NULL OR ANULADO <> 1)

	SELECT COUNT(ID_DETALLE) AS abonos_realizados, SUM(VALOR_ABONADO) AS total_por_abonos FROM DETALLE_ABONOS_COMPRAS WHERE IDX_FORMA_PAGO <> 2 AND IDX_CAJA = @caja AND IDX_COMPRA IN (SELECT ID_COMPRA FROM COMPRAS WHERE ANULADO IS NULL OR ANULADO <> 1)

	SELECT FORMA_PAGO as forma, SUM(COSTO_TOTAL) AS valor FROM FACTURAS
	INNER JOIN FORMAS_PAGO ON FACTURAS.IDX_FORMA_PAGO = FORMAS_PAGO.ID_FORMA_PAGO
	WHERE IDX_FORMA_PAGO <> 2 AND IDX_CAJA = @caja AND (ANULADO IS NULL OR ANULADO <> 1)
	GROUP BY FORMA_PAGO

	--Dinero a credito (excluye anuladas)
	SELECT COUNT(ID_FACTURA) AS creditos_creados, SUM(COSTO_TOTAL) - SUM(VALOR_PAGADO) AS valor_adeudado FROM FACTURAS WHERE IDX_FORMA_PAGO = 2 AND IDX_CAJA = @caja AND (ANULADO IS NULL OR ANULADO <> 1)
	SELECT COUNT(ID_COMPRA) AS creditos_adquiridos, SUM(COSTO_TOTAL) - SUM(VALOR_PAGADO) AS valor_adeudado FROM COMPRAS WHERE CREDITO = 1 AND IDX_CAJA = @caja AND (ANULADO IS NULL OR ANULADO <> 1)

	--Dinero de apertura de caja
	SELECT FORMA_PAGO AS denominacion, SUM(SALDO) AS dinero_abrir_caja
	FROM SALDOS_APERTURA_CAJA
	INNER JOIN FORMAS_PAGO ON SALDOS_APERTURA_CAJA.IDX_DENOMINACION = FORMAS_PAGO.ID_FORMA_PAGO
	WHERE IDX_CAJA = @caja
	GROUP BY FORMA_PAGO

	SELECT TIPO_MOVIMIENTO AS denominacion, CASE IDX_GASTO WHEN 0 THEN MOVIMIENTOS_CAJA.DESCRIPCION ELSE GASTOS.NOMBRE END AS gasto, FECHA_MOVIMIENTO AS fecha, FORMA_PAGO AS forma, VALOR as dinero_abrir_caja FROM MOVIMIENTOS_CAJA
	INNER JOIN TIPO_MOVIMIENTOS ON MOVIMIENTOS_CAJA.IDX_TIPO_MOVIMIENTO = TIPO_MOVIMIENTOS.ID_TIPO_MOVIMIENTO
	INNER JOIN FORMAS_PAGO ON MOVIMIENTOS_CAJA.IDX_DENOMINACION = FORMAS_PAGO.ID_FORMA_PAGO
	LEFT JOIN GASTOS ON MOVIMIENTOS_CAJA.IDX_GASTO = GASTOS.ID_GASTO

	WHERE IDX_CAJA = @caja


	--Caja real (excluye facturas/compras/abonos de documentos anulados)
SELECT
  FP.FORMA_PAGO AS forma_pago,
  SUM(
    ISNULL(FPAGOS.total_factura, 0) +
    ISNULL(INICIALES.total_pago_inicial, 0) +
    ISNULL(AV.VALOR_ABONADO, 0) -
    ISNULL(AC.VALOR_ABONADO, 0) -
    ISNULL(CP.VALOR_COMPRAS, 0)
  ) AS total
FROM FORMAS_PAGO FP

LEFT JOIN (
  SELECT IDX_FORMA_PAGO, SUM(COSTO_TOTAL) AS total_factura
  FROM FACTURAS
  WHERE IDX_CAJA = @caja AND IDX_FORMA_PAGO <> 2 AND (ANULADO IS NULL OR ANULADO <> 1)
  GROUP BY IDX_FORMA_PAGO
) FPAGOS ON FPAGOS.IDX_FORMA_PAGO = FP.ID_FORMA_PAGO

LEFT JOIN (
  SELECT IDX_FORMA_PAGO, SUM(PAGO_INICIAL) AS total_pago_inicial
  FROM FACTURAS
  WHERE IDX_CAJA = @caja AND IDX_FORMA_PAGO = 2 AND PAGO_INICIAL > 0 AND (ANULADO IS NULL OR ANULADO <> 1)
  GROUP BY IDX_FORMA_PAGO
) INICIALES ON INICIALES.IDX_FORMA_PAGO = FP.ID_FORMA_PAGO

LEFT JOIN DETALLE_ABONOS_VENTAS AV ON AV.IDX_CAJA = @caja AND AV.IDX_FORMA_PAGO = FP.ID_FORMA_PAGO
    AND AV.IDX_FACTURA IN (SELECT ID_FACTURA FROM FACTURAS WHERE ANULADO IS NULL OR ANULADO <> 1)
LEFT JOIN DETALLE_ABONOS_COMPRAS AC ON AC.IDX_CAJA = @caja AND AC.IDX_FORMA_PAGO = FP.ID_FORMA_PAGO
    AND AC.IDX_COMPRA IN (SELECT ID_COMPRA FROM COMPRAS WHERE ANULADO IS NULL OR ANULADO <> 1)

-- Resta de compras por forma de pago (CREDITO, no IDX_FORMA_PAGO: ver nota arriba)
LEFT JOIN (
  SELECT IDX_FORMA_PAGO, SUM(COSTO_TOTAL) AS VALOR_COMPRAS
  FROM COMPRAS
  WHERE IDX_CAJA = @caja AND (CREDITO IS NULL OR CREDITO <> 1) AND (ANULADO IS NULL OR ANULADO <> 1)
  GROUP BY IDX_FORMA_PAGO
) CP ON CP.IDX_FORMA_PAGO = FP.ID_FORMA_PAGO

GROUP BY FP.FORMA_PAGO

SELECT
  (
    -- Ingresos (excluye anuladas)
    ISNULL((SELECT SUM(COSTO_TOTAL) FROM FACTURAS WHERE IDX_CAJA = @caja AND IDX_FORMA_PAGO <> 2 AND (ANULADO IS NULL OR ANULADO <> 1)), 0) +
    ISNULL((SELECT SUM(PAGO_INICIAL) FROM FACTURAS WHERE IDX_CAJA = @caja AND IDX_FORMA_PAGO = 2 AND (ANULADO IS NULL OR ANULADO <> 1)), 0) +
    ISNULL((SELECT SUM(VALOR_ABONADO) FROM DETALLE_ABONOS_VENTAS WHERE IDX_CAJA = @caja AND IDX_FORMA_PAGO <> 2 AND IDX_FACTURA IN (SELECT ID_FACTURA FROM FACTURAS WHERE ANULADO IS NULL OR ANULADO <> 1)), 0) +
	ISNULL((SELECT SUM(SALDO) FROM SALDOS_APERTURA_CAJA WHERE IDX_CAJA = @caja),0) +
	ISNULL((SELECT SUM(VALOR) FROM MOVIMIENTOS_CAJA WHERE IDX_CAJA = @caja AND IDX_TIPO_MOVIMIENTO = 1),0)
  )
  -
  (
    -- Egresos (excluye anuladas; CREDITO en vez de IDX_FORMA_PAGO para COMPRAS)
    ISNULL((SELECT SUM(COSTO_TOTAL) FROM COMPRAS WHERE IDX_CAJA = @caja AND (CREDITO IS NULL OR CREDITO <> 1) AND (ANULADO IS NULL OR ANULADO <> 1)), 0) +
    ISNULL((SELECT SUM(PAGO_INICIAL) FROM COMPRAS WHERE IDX_CAJA = @caja AND CREDITO = 1 AND (ANULADO IS NULL OR ANULADO <> 1)), 0) +
    ISNULL((SELECT SUM(VALOR_ABONADO) FROM DETALLE_ABONOS_COMPRAS WHERE IDX_CAJA = @caja AND IDX_FORMA_PAGO <> 2 AND IDX_COMPRA IN (SELECT ID_COMPRA FROM COMPRAS WHERE ANULADO IS NULL OR ANULADO <> 1)), 0) +
	ISNULL((SELECT SUM(VALOR) FROM MOVIMIENTOS_CAJA WHERE IDX_CAJA = @caja AND IDX_TIPO_MOVIMIENTO = 2),0)
  ) AS total_real_en_caja

	END
END
GO

-- =====================================================================================
-- 5. SP_ABONOS_COMPRAS — excluir compras anuladas de la rama 'COMPRAS'
--    (pantalla abonos-compras: espejo del filtro que ya tiene SP_ABONOS_VENTAS
--    para su rama 'FACTURAS')
-- =====================================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[SP_ABONOS_COMPRAS]
    @OPERACION          VARCHAR(10),
    @ID_DETALLE         NUMERIC(18,0)  = NULL,
    @IDX_COMPRA         NUMERIC(18,0)  = NULL,
    @IDX_USUARIO        NUMERIC(18,0)  = NULL,
    @IDX_PROVEEDOR      NUMERIC(18,0)  = NULL,
    @IDX_FORMA_PAGO     NUMERIC(18,0)  = NULL,
    @IDX_CLIENTE        NUMERIC(18,0)  = NULL,
    @BIT_PAGA_CLIENTE   NUMERIC(18,0)  = NULL,
    @VALOR_ABONADO      DECIMAL(18,2)  = NULL,
    @COMENTARIO         VARCHAR(100)   = NULL,
    @ESTADO             BIT            = NULL,
    @PAGO_TOTAL         BIT            = NULL,
    @FECHA_FINAL        DATETIME       = NULL,
    @FECHA_INICIAL      DATETIME       = NULL,
    @PAGINA             INT            = 1,
    @TAMANO_PAGINA      INT            = 10
AS
BEGIN
    SET NOCOUNT ON;

    IF @OPERACION = 'ABONOS'
        BEGIN
            SELECT
                IDX_COMPRA, IDX_USUARIO, DAC.IDX_FORMA_PAGO,
                DP.NOMBRES + ' ' + DP.APELLIDOS             AS USUARIO,
                DAC.FECHA_ABONO, DAC.VALOR_ABONADO,
                FP.FORMA_PAGO,
                C.NOMBRES + ' ' + C.APELLIDOS               AS CLIENTE,
                ISNULL(DAC.BIT_PAGA_CLIENTE, 0)             AS bit_paga_cliente,
                DAC.COMENTARIO
            FROM DETALLE_ABONOS_COMPRAS DAC
            INNER JOIN USUARIOS         U  ON DAC.IDX_USUARIO = U.USUARIO_ID
            INNER JOIN DATOS_PERSONALES DP ON U.IDX_DATOS_PERSONALES = DP.DATOS_PERSONALES_ID
            LEFT  JOIN FORMAS_PAGO      FP ON DAC.IDX_FORMA_PAGO = FP.ID_FORMA_PAGO
            LEFT  JOIN CLIENTES         C  ON DAC.IDX_CLIENTE = C.CLIENTE_ID
            WHERE @IDX_COMPRA IS NULL OR DAC.IDX_COMPRA = @IDX_COMPRA
        END
    ELSE IF @OPERACION = 'COMPRAS'
        BEGIN
            SELECT
                PR.RAZON_SOCIAL,
                (CP.COSTO_TOTAL - CP.VALOR_PAGADO)  AS RESTANTE,
                CP.COSTO_TOTAL,
                CP.FECHA_COMPRA,
                CP.IDX_PROVEEDOR,
                CP.ID_COMPRA,
                CP.PAGO_INICIAL,
                FORMAS_PAGO.FORMA_PAGO,
                COUNT(*) OVER()                     AS total_registros
            FROM COMPRAS CP
            INNER JOIN PROVEEDORES PR  ON CP.IDX_PROVEEDOR          = PR.ID_PROVEEDOR
            LEFT  JOIN FORMAS_PAGO     ON CP.IDX_FORMA_PAGO_INICIAL = FORMAS_PAGO.ID_FORMA_PAGO
            WHERE CP.CREDITO = 1   -- ← antes usaba IDX_FORMA_PAGO = 2, que no es confiable en Comprar
              AND (CP.ANULADO IS NULL OR CP.ANULADO <> 1)   -- ← excluye anuladas
              AND (@FECHA_INICIAL IS NULL OR CP.FECHA_COMPRA > @FECHA_INICIAL)
              AND (@FECHA_FINAL   IS NULL OR CP.FECHA_COMPRA < @FECHA_FINAL)
              AND (@IDX_PROVEEDOR IS NULL OR CP.IDX_PROVEEDOR = @IDX_PROVEEDOR)
            ORDER BY (CP.COSTO_TOTAL - CP.VALOR_PAGADO) DESC
            OFFSET (@PAGINA - 1) * @TAMANO_PAGINA ROWS
            FETCH NEXT @TAMANO_PAGINA ROWS ONLY;
        END
    ELSE IF @OPERACION = 'INSERT'
        BEGIN
            DECLARE @PAGO_REALIZADO_A_LA_FECHA  DECIMAL(18,2) = (SELECT TOP 1 ISNULL(VALOR_PAGADO,0)    FROM COMPRAS     WHERE ID_COMPRA    = @IDX_COMPRA)
            DECLARE @COSTO_TOTAL                DECIMAL(18,2) = (SELECT TOP 1 ISNULL(COSTO_TOTAL,0)     FROM COMPRAS     WHERE ID_COMPRA    = @IDX_COMPRA)
            DECLARE @SALDO_PENDIENTE_PROVEEDOR  DECIMAL(18,2) = (SELECT TOP 1 ISNULL(SALDO_PENDIENTE,0) FROM PROVEEDORES WHERE ID_PROVEEDOR = @IDX_PROVEEDOR)
            DECLARE @caja                       NUMERIC(18,0) = (SELECT TOP 1 ID_CAJA FROM CAJA WHERE IDX_USUARIO = @IDX_USUARIO AND FECHA_CIERRE_CAJA IS NULL)

            IF @PAGO_TOTAL = 1
                BEGIN
                    UPDATE COMPRAS SET VALOR_PAGADO = @COSTO_TOTAL WHERE ID_COMPRA = @IDX_COMPRA
                    SET @SALDO_PENDIENTE_PROVEEDOR = @SALDO_PENDIENTE_PROVEEDOR - (@COSTO_TOTAL - @PAGO_REALIZADO_A_LA_FECHA)
                    SET @VALOR_ABONADO = @COSTO_TOTAL - @PAGO_REALIZADO_A_LA_FECHA
                    UPDATE PROVEEDORES SET SALDO_PENDIENTE = @SALDO_PENDIENTE_PROVEEDOR WHERE ID_PROVEEDOR = @IDX_PROVEEDOR
                END
            ELSE
                BEGIN
                    SET @PAGO_REALIZADO_A_LA_FECHA = @PAGO_REALIZADO_A_LA_FECHA + @VALOR_ABONADO
                    UPDATE COMPRAS SET VALOR_PAGADO = @PAGO_REALIZADO_A_LA_FECHA WHERE ID_COMPRA = @IDX_COMPRA
                    SET @SALDO_PENDIENTE_PROVEEDOR = @SALDO_PENDIENTE_PROVEEDOR - @VALOR_ABONADO
                    UPDATE PROVEEDORES SET SALDO_PENDIENTE = @SALDO_PENDIENTE_PROVEEDOR WHERE ID_PROVEEDOR = @IDX_PROVEEDOR
                END

            INSERT INTO DETALLE_ABONOS_COMPRAS (IDX_COMPRA, IDX_USUARIO, IDX_FORMA_PAGO, VALOR_ABONADO, FECHA_ABONO, COMENTARIO, ESTADO, IDX_CAJA, IDX_CLIENTE, BIT_PAGA_CLIENTE)
            VALUES (@IDX_COMPRA, @IDX_USUARIO, @IDX_FORMA_PAGO, @VALOR_ABONADO, GETDATE(), @COMENTARIO, 1, @caja, @IDX_CLIENTE, @BIT_PAGA_CLIENTE)
        END
END
GO

-- =====================================================================================
-- 6. SP_BALANCE_PERIODOS — excluir compras anuladas del CTE de compras
-- =====================================================================================
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
        WHERE (ANULADO IS NULL OR ANULADO <> 1)   -- ← excluye anuladas
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

-- =====================================================================================
-- 7. SP_CARGADO_COMPRAS / SP_CARGADO_COMPRAS_V2 — exponer ANULADO/ANULADO_FECHA
--    (no se filtra: el informe debe SEGUIR MOSTRANDO la compra, marcada como anulada)
-- =====================================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[SP_CARGADO_COMPRAS]
	@todas bit,
	@fechaInicial datetime = null,
	@fechaFinal datetime = null,
	@proveedor decimal,
	@usuario decimal
AS
BEGIN
	SET NOCOUNT ON;

	SELECT C.ID_COMPRA, C.COSTO_TOTAL, C.IDX_PROVEEDOR, C.IDX_USUARIO_COMPRADOR, FP.FORMA_PAGO AS forma_pago, C.IDX_FORMA_PAGO AS medio, FORMAT(C.FECHA_COMPRA, 'dd/MM/yyyy hh:mm tt') as FECHA_COMPRA,
	PV.RAZON_SOCIAL AS PROVEEDOR, PV.TELEFONO AS  TELEFONO_PROVEEDOR,
	CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS) AS USUARIO_NOMBRE, DP.NUMERO_TELEFONO AS TELEFONO_USUARIO,
	C.VALOR_PAGADO AS pagado, C.ANULADO, C.ANULADO_FECHA, ISNULL(C.CREDITO,0) AS CREDITO

	INTO #COMPRAS

	FROM COMPRAS C
	INNER JOIN PROVEEDORES PV ON C.IDX_PROVEEDOR = PV.ID_PROVEEDOR
	INNER JOIN USUARIOS US ON C.IDX_USUARIO_COMPRADOR = US.USUARIO_ID
	INNER JOIN DATOS_PERSONALES DP ON US.IDX_DATOS_PERSONALES = DP.DATOS_PERSONALES_ID
	INNER JOIN FORMAS_PAGO FP ON C.IDX_FORMA_PAGO = FP.ID_FORMA_PAGO
	WHERE ((C.FECHA_COMPRA >= isnull(@fechaInicial,C.FECHA_COMPRA) AND C.FECHA_COMPRA <= isnull(@fechaFinal,C.FECHA_COMPRA)) OR @todas = 1)
	AND (C.IDX_USUARIO_COMPRADOR = @usuario OR @usuario = 0)
	AND (C.IDX_PROVEEDOR = @proveedor OR @proveedor = 0)

	--Mostrar todas las compras
	SELECT * FROM #COMPRAS

	--Mostrar los productos comprados
	SELECT CD.IDX_COMPRA,CD.CANTIDAD, CD.COSTO, CD.COSTO / CD.CANTIDAD AS valor_comprado,
	P.PRODUCTO,
	P.COSTO_X_UNIDAD, MP.EQUIVALENCIA_MEDIDA, case MP.IDX_TIPO_MEDIDA WHEN 1 THEN '' ELSE CASE CD.CANTIDAD WHEN 1 THEN 'unidad' ELSE 'unidades' END END AS EQUIVALENCIA, GRAMAJE_COMPRADO

	FROM COMPRAS_DETALLES CD
	INNER JOIN PRODUCTOS P ON CD.IDX_PRODUCTO = P.PRODUCT_ID
	LEFT JOIN MEDIDAS_PESADO MP ON P.IDX_MEDIDA = MP.ID_MEDIDAS_PESADO

	WHERE CD.IDX_COMPRA IN (SELECT ID_COMPRA FROM #COMPRAS)

	DROP TABLE #COMPRAS

END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[SP_CARGADO_COMPRAS_V2]
    @todas              bit,
    @fechaInicial       datetime = null,
    @fechaFinal         datetime = null,
    @proveedor          decimal,
    @usuario            decimal,
    @pagina             int = 1,
    @registros_por_pagina int = 10
AS
BEGIN
    SET NOCOUNT ON;

    SELECT C.ID_COMPRA, C.COSTO_TOTAL, C.IDX_PROVEEDOR, C.IDX_USUARIO_COMPRADOR,
           FP.FORMA_PAGO AS forma_pago, C.IDX_FORMA_PAGO AS medio,
           FORMAT(C.FECHA_COMPRA, 'dd/MM/yyyy hh:mm tt') AS FECHA_COMPRA,
           PV.RAZON_SOCIAL AS PROVEEDOR, PV.TELEFONO AS TELEFONO_PROVEEDOR,
           CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS) AS USUARIO_NOMBRE,
           DP.NUMERO_TELEFONO AS TELEFONO_USUARIO,
           C.VALOR_PAGADO AS pagado, C.ANULADO, C.ANULADO_FECHA, ISNULL(C.CREDITO,0) AS CREDITO
    INTO #COMPRAS
    FROM COMPRAS C
    INNER JOIN PROVEEDORES PV ON C.IDX_PROVEEDOR = PV.ID_PROVEEDOR
    INNER JOIN USUARIOS US ON C.IDX_USUARIO_COMPRADOR = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES DP ON US.IDX_DATOS_PERSONALES = DP.DATOS_PERSONALES_ID
    INNER JOIN FORMAS_PAGO FP ON C.IDX_FORMA_PAGO = FP.ID_FORMA_PAGO
    WHERE ((C.FECHA_COMPRA >= ISNULL(@fechaInicial, C.FECHA_COMPRA)
            AND C.FECHA_COMPRA <= ISNULL(@fechaFinal, C.FECHA_COMPRA))
           OR @todas = 1)
      AND (C.IDX_USUARIO_COMPRADOR = @usuario OR @usuario = 0)
      AND (C.IDX_PROVEEDOR = @proveedor OR @proveedor = 0);

    -- IDs de la página actual
    SELECT ID_COMPRA
    INTO #PAGINA
    FROM #COMPRAS
    ORDER BY ID_COMPRA DESC
    OFFSET (@pagina - 1) * @registros_por_pagina ROWS
    FETCH NEXT @registros_por_pagina ROWS ONLY;

    -- Resultado 1: registros de la página
    SELECT * FROM #COMPRAS
    WHERE ID_COMPRA IN (SELECT ID_COMPRA FROM #PAGINA)
    ORDER BY ID_COMPRA DESC;

    -- Resultado 2: productos comprados en esta página
    SELECT CD.IDX_COMPRA, CD.CANTIDAD, CD.COSTO, CD.COSTO / CD.CANTIDAD AS valor_comprado,
           P.PRODUCTO, P.COSTO_X_UNIDAD, MP.EQUIVALENCIA_MEDIDA,
           CASE MP.IDX_TIPO_MEDIDA
               WHEN 1 THEN ''
               ELSE CASE CD.CANTIDAD WHEN 1 THEN 'unidad' ELSE 'unidades' END
           END AS EQUIVALENCIA,
           GRAMAJE_COMPRADO
    FROM COMPRAS_DETALLES CD
    INNER JOIN PRODUCTOS P ON CD.IDX_PRODUCTO = P.PRODUCT_ID
    LEFT JOIN MEDIDAS_PESADO MP ON P.IDX_MEDIDA = MP.ID_MEDIDAS_PESADO
    WHERE CD.IDX_COMPRA IN (SELECT ID_COMPRA FROM #PAGINA);

    -- Resultado 3: total de registros (para el paginador Angular)
    SELECT COUNT(*) AS total_registros FROM #COMPRAS;

    DROP TABLE #PAGINA;
    DROP TABLE #COMPRAS;
END
GO

-- =====================================================================================
-- 8. SP_CARGADO_FACTURAS_V2 — exponer ANULADO/ANULADO_FECHA (hoy no lo exponia,
--    a diferencia de SP_CARGADO_FACTURAS V1)
-- =====================================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[SP_CARGADO_FACTURAS_V2]
    @todas              bit,
    @fechaInicial       datetime = null,
    @fechaFinal         datetime = null,
    @cliente            decimal,
    @usuario            decimal,
    @pagina             int = 1,
    @registros_por_pagina int = 10
AS
BEGIN
    SET NOCOUNT ON;

    SELECT FC.ID_FACTURA, FC.COSTO_TOTAL, FC.IDX_CLIENTE, FC.IDX_USUARIO,
           FP.FORMA_PAGO AS forma_pago, FC.IDX_FORMA_PAGO AS medio,
           FORMAT(FC.FECHA_VENTA, 'dd/MM/yyyy hh:mm tt') AS FECHA_VENTA,
           CONCAT(CL.NOMBRES, ' ', CL.APELLIDOS) AS CLIENTE_NOMBRE,
           CL.NUMERO_TELEFONO AS TELEFONO_CLIENTE,
           CONCAT(DP.NOMBRES, ' ', DP.APELLIDOS) AS USUARIO_NOMBRE,
           DP.NUMERO_TELEFONO AS TELEFONO_USUARIO,
           FC.CONSUMIDOR_FINAL, FC.VALOR_IVA,
           FC.VALOR_PAGADO AS pagado, FC.ANULADO, FC.ANULADO_FECHA
    INTO #CLIENTES
    FROM FACTURAS FC
    INNER JOIN CLIENTES CL ON FC.IDX_CLIENTE = CL.CLIENTE_ID
    INNER JOIN USUARIOS US ON FC.IDX_USUARIO = US.USUARIO_ID
    INNER JOIN DATOS_PERSONALES DP ON US.IDX_DATOS_PERSONALES = DP.DATOS_PERSONALES_ID
    INNER JOIN FORMAS_PAGO FP ON FC.IDX_FORMA_PAGO = FP.ID_FORMA_PAGO
    WHERE ((FC.FECHA_VENTA >= ISNULL(@fechaInicial, FC.FECHA_VENTA)
            AND FC.FECHA_VENTA <= ISNULL(@fechaFinal, FC.FECHA_VENTA))
           OR @todas = 1)
      AND (FC.IDX_USUARIO = @usuario OR @usuario = 0)
      AND (FC.IDX_CLIENTE = @cliente OR @cliente = 0);

    -- IDs de la página actual
    SELECT ID_FACTURA
    INTO #PAGINA
    FROM #CLIENTES
    ORDER BY ID_FACTURA DESC
    OFFSET (@pagina - 1) * @registros_por_pagina ROWS
    FETCH NEXT @registros_por_pagina ROWS ONLY;

    -- Resultado 1: registros de la página
    SELECT * FROM #CLIENTES
    WHERE ID_FACTURA IN (SELECT ID_FACTURA FROM #PAGINA)
    ORDER BY ID_FACTURA DESC;

    -- Resultado 2: productos vendidos en esta página
    SELECT VP.IDX_FACTURA, VP.QUANTITY, VP.TOTAL_COST,
           VP.COSTO_UNITARIO_AL_VENDER AS valor_vendido,
           P.PRODUCTO, P.COSTO_X_UNIDAD, VP.SUB_TOTAL, VP.VALOR_IVA,
           MP.EQUIVALENCIA_MEDIDA,
           CASE MP.IDX_TIPO_MEDIDA
               WHEN 1 THEN ''
               ELSE CASE VP.QUANTITY WHEN 1 THEN 'unidad' ELSE 'unidades' END
           END AS EQUIVALENCIA,
           GRAMAJE_VENDIDO
    FROM VENDIDO_PRODUCTOS VP
    INNER JOIN PRODUCTOS P ON VP.IDX_PRODUCTO = P.PRODUCT_ID
    LEFT JOIN MEDIDAS_PESADO MP ON P.IDX_MEDIDA = MP.ID_MEDIDAS_PESADO
    WHERE VP.IDX_FACTURA IN (SELECT ID_FACTURA FROM #PAGINA);

    -- Resultado 3: servicios vendidos en esta página
    SELECT SD.*, S.COSTO_REGULAR, S.SERVICIO
    FROM SERVICIOS_DADOS SD
    INNER JOIN SERVICIOS S ON SD.IDX_SERVICIO = S.SERVICIO_ID
    WHERE SD.IDX_FACTURA IN (SELECT ID_FACTURA FROM #PAGINA);

    -- Resultado 4: total de registros (para el paginador Angular)
    SELECT COUNT(*) AS total_registros FROM #CLIENTES;

    DROP TABLE #PAGINA;
    DROP TABLE #CLIENTES;
END
GO

-- =====================================================================================
-- 9. SP_CARGAR_TOTALIZADO — excluir facturas/compras anuladas de los totales
-- =====================================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[SP_CARGAR_TOTALIZADO]
	@fecha_inicial datetime = null,
	@fecha_final datetime = null
AS
BEGIN



SELECT COUNT(CLIENTE_ID) AS TOTAL_CLIENTES FROM CLIENTES WHERE FECHA_CREACION >= @fecha_inicial	AND FECHA_CREACION <= @fecha_final

SELECT SUM(GRAMAJE_DEL_PRODUCTO) AS TOTAL_PRODUCTOS, SUM(COSTO_X_UNIDAD * GRAMAJE_DEL_PRODUCTO) AS TOTAL_VALOR FROM PRODUCTOS

SELECT PRODUCTO, GRAMAJE_DEL_PRODUCTO, COSTO_X_UNIDAD * GRAMAJE_DEL_PRODUCTO AS VALOR_PRODUCTO FROM PRODUCTOS

SELECT SUM(QUANTITY) AS TOTAL_ACTIVOS, SUM(QUANTITY*COSTO_X_UNIDAD) AS TOTAL_VALOR FROM ACTIVOS

SELECT ACTIVO, QUANTITY, (QUANTITY * COSTO_X_UNIDAD) AS VALOR_ACTIVOS FROM ACTIVOS

SELECT COUNT(APPT_ID) AS TOTAL_CITAS FROM CITAS WHERE FECHA_CITA >= @fecha_inicial AND FECHA_CITA <= @fecha_final

SELECT COUNT(IDX_ESTADOS) AS CANTIDAD_CITAS, IDX_ESTADOS, CITAS_ESTADOS.CITAS_ESTADOS FROM CITAS
INNER JOIN CITAS_ESTADOS ON CITAS.IDX_ESTADOS = CITAS_ESTADOS.ESTADOS_ID
WHERE FECHA_CITA >= @fecha_inicial AND FECHA_CITA <= @fecha_final
GROUP BY IDX_ESTADOS, CITAS_ESTADOS.CITAS_ESTADOS

SELECT COUNT(ID_COMPRA) AS TOTAL_COMPRAS FROM COMPRAS WHERE FECHA_COMPRA >= @fecha_inicial AND FECHA_COMPRA <= @fecha_final AND (ANULADO IS NULL OR ANULADO <> 1)

SELECT SUM(COSTO_TOTAL) AS TOTAL_DINERO_COMPRAS FROM COMPRAS WHERE FECHA_COMPRA >= @fecha_inicial AND FECHA_COMPRA <= @fecha_final AND (ANULADO IS NULL OR ANULADO <> 1)

SELECT COUNT(IDX_USUARIO_COMPRADOR) AS CANTIDAD_COMPRAS, SUM(COSTO_TOTAL) AS COMPRA_TOTAL, DATOS_PERSONALES.NOMBRES FROM COMPRAS
INNER JOIN USUARIOS ON COMPRAS.IDX_USUARIO_COMPRADOR = USUARIOS.USUARIO_ID
INNER JOIN DATOS_PERSONALES ON USUARIOS.IDX_DATOS_PERSONALES = DATOS_PERSONALES.DATOS_PERSONALES_ID
WHERE FECHA_COMPRA >= @fecha_inicial AND FECHA_COMPRA <= @fecha_final AND (COMPRAS.ANULADO IS NULL OR COMPRAS.ANULADO <> 1)
GROUP BY IDX_USUARIO_COMPRADOR, NOMBRES

SELECT COUNT(ID_FACTURA) AS TOTAL_FACTURAS FROM FACTURAS WHERE FECHA_VENTA >= @fecha_inicial AND FECHA_VENTA <= @fecha_final AND (ANULADO IS NULL OR ANULADO <> 1)

SELECT COUNT(IDX_CLIENTE) AS CANTIDAD_FACTURAS_COMPRADAS, NOMBRES FROM FACTURAS
INNER JOIN CLIENTES ON FACTURAS.IDX_CLIENTE = CLIENTES.CLIENTE_ID
WHERE FECHA_VENTA >= @fecha_inicial AND FECHA_VENTA <= @fecha_final AND (FACTURAS.ANULADO IS NULL OR FACTURAS.ANULADO <> 1)
GROUP BY IDX_CLIENTE, NOMBRES

SELECT COUNT(IDX_USUARIO) AS CANTIDAD_FACTURAS_CREADAS, NOMBRES FROM FACTURAS
INNER JOIN USUARIOS ON FACTURAS.IDX_USUARIO = USUARIOS.USUARIO_ID
INNER JOIN DATOS_PERSONALES ON USUARIOS.IDX_DATOS_PERSONALES = DATOS_PERSONALES.DATOS_PERSONALES_ID
WHERE FECHA_VENTA >= @fecha_inicial AND FECHA_VENTA <= @fecha_final AND (FACTURAS.ANULADO IS NULL OR FACTURAS.ANULADO <> 1)
GROUP BY IDX_USUARIO, NOMBRES

SELECT COUNT(SERVICIO_DADOS_ID) AS TOTAL_SERVICIOS_DADOS FROM SERVICIOS_DADOS WHERE FECHA_SERVICIO_DADO >= @fecha_inicial AND FECHA_SERVICIO_DADO <= @fecha_final

SELECT COUNT(IDX_SERVICIO) AS CATIDAD_SERVICIOS_DATOS, SERVICIO FROM SERVICIOS_DADOS
INNER JOIN SERVICIOS ON SERVICIOS_DADOS.IDX_SERVICIO = SERVICIOS.SERVICIO_ID
WHERE FECHA_SERVICIO_DADO >= @fecha_inicial AND FECHA_SERVICIO_DADO <= @fecha_final
GROUP BY IDX_SERVICIO, SERVICIO

SELECT PRODUCTOS.PRODUCTO,COUNT(IDX_PRODUCTO) AS VECES_VENDIDO, SUM(VENDIDO_PRODUCTOS.QUANTITY) AS TOTAL_VENDIDOS, SUM(TOTAL_COST) AS DINERO_GENERADO FROM VENDIDO_PRODUCTOS
INNER JOIN PRODUCTOS ON VENDIDO_PRODUCTOS.IDX_PRODUCTO = PRODUCTOS.PRODUCT_ID
INNER JOIN FACTURAS ON VENDIDO_PRODUCTOS.IDX_FACTURA = FACTURAS.ID_FACTURA
WHERE FECHA_VENTA >= @fecha_inicial AND FECHA_VENTA <= @fecha_final AND (FACTURAS.ANULADO IS NULL OR FACTURAS.ANULADO <> 1)
GROUP BY IDX_PRODUCTO, PRODUCTO

SELECT NOMBRES + ' ' + APELLIDOS AS NOMBRES, NUMERO_TELEFONO FROM CLIENTES WHERE FECHA_CREACION >= @fecha_inicial	AND FECHA_CREACION <= @fecha_final
END
GO

-- =====================================================================================
-- 10. SP_COMPRAS_ACCIONES — excluir compras anuladas del dropdown/restante
-- =====================================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[SP_COMPRAS_ACCIONES]
AS
BEGIN
	SELECT ID_COMPRA AS compra, IDX_PROVEEDOR AS id_proveedor, PV.RAZON_SOCIAL AS proveedor, C.COSTO_TOTAL - C.VALOR_PAGADO AS restante
	FROM COMPRAS C
	INNER JOIN PROVEEDORES PV ON C.IDX_PROVEEDOR = PV.ID_PROVEEDOR
	WHERE (C.ANULADO IS NULL OR C.ANULADO <> 1)   -- ← excluye anuladas
END
GO

-- =====================================================================================
-- 11. SP_LISTADO_PERIODOS — excluir compras anuladas del resultado de compras
--     (el resultado de facturas ya las excluia)
-- =====================================================================================
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

    -- Resultado 2: Compras del periodo (excluye anuladas)
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
      AND (C.ANULADO IS NULL OR C.ANULADO <> 1)   -- ← excluye anuladas
    ORDER BY C.FECHA_COMPRA DESC;
END
GO

-- =====================================================================================
-- 12. SP_INFORME_ABONOS_CLIENTES / SP_INFORME_ABONOS_PROVEEDORES — exponer si el
--     documento padre esta anulado (ledger historico: NO se filtra/oculta, solo
--     se marca, para preservar trazabilidad de auditoria)
-- =====================================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[SP_INFORME_ABONOS_CLIENTES]
@FECHA_INICIAL datetime = NULL,
@FECHA_FINAL datetime = NULL,
@IDX_CLIENTE int = 0,
@IDX_PROVEEDOR int = 0

AS
BEGIN

SELECT IDX_FACTURA, DAV.IDX_USUARIO, DP.NOMBRES + ' ' + DP.APELLIDOS AS USUARIO, CL.NOMBRES + ' ' + CL.APELLIDOS AS CLIENTE, DAV.IDX_CLIENTE, DAV.IDX_FORMA_PAGO, VALOR_ABONADO, COMENTARIO, FECHA_ABONO, FP.FORMA_PAGO, ISNULL(FAC.ANULADO, 0) AS factura_anulada

FROM DETALLE_ABONOS_VENTAS DAV
INNER JOIN USUARIOS U ON DAV.IDX_USUARIO = U.USUARIO_ID
INNER JOIN DATOS_PERSONALES DP ON U.IDX_DATOS_PERSONALES = DP.DATOS_PERSONALES_ID
LEFT JOIN FORMAS_PAGO FP ON DAV.IDX_FORMA_PAGO = FP.ID_FORMA_PAGO
INNER JOIN FACTURAS FAC ON DAV.IDX_FACTURA = FAC.ID_FACTURA
INNER JOIN CLIENTES CL ON DAV.IDX_CLIENTE = CL.CLIENTE_ID

WHERE (@IDX_CLIENTE = 0 OR FAC.IDX_CLIENTE = @IDX_CLIENTE) AND
(@FECHA_INICIAL IS NULL OR FECHA_ABONO > @FECHA_INICIAL) AND
(@FECHA_FINAL IS NULL OR FECHA_ABONO < @FECHA_FINAL)

END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[SP_INFORME_ABONOS_PROVEEDORES]
@FECHA_INICIAL datetime = NULL,
@FECHA_FINAL datetime = NULL,
@IDX_PROVEEDOR int = 0,
@IDX_CLIENTE int = 0

AS
BEGIN


SELECT IDX_COMPRA, IDX_USUARIO, DAC.IDX_FORMA_PAGO, DP.NOMBRES + ' '+ DP.APELLIDOS AS USUARIO, PR.RAZON_SOCIAL, DAC.FECHA_ABONO, DAC.VALOR_ABONADO, FP.FORMA_PAGO, C.NOMBRES + ' ' +C.APELLIDOS AS CLIENTE, ISNULL(DAC.BIT_PAGA_CLIENTE,0) AS bit_paga_cliente, DAC.COMENTARIO, ISNULL(COM.ANULADO, 0) AS compra_anulada

FROM DETALLE_ABONOS_COMPRAS DAC
INNER JOIN USUARIOS U ON DAC.IDX_USUARIO= U.USUARIO_ID
INNER JOIN DATOS_PERSONALES DP ON U.IDX_DATOS_PERSONALES = DP.DATOS_PERSONALES_ID
LEFT JOIN FORMAS_PAGO FP ON DAC.IDX_FORMA_PAGO = FP.ID_FORMA_PAGO
LEFT JOIN CLIENTES C ON DAC.IDX_CLIENTE = C.CLIENTE_ID
INNER JOIN COMPRAS COM ON DAC.IDX_COMPRA = COM.ID_COMPRA
INNER JOIN PROVEEDORES PR ON COM.IDX_PROVEEDOR = PR.ID_PROVEEDOR

WHERE (@IDX_PROVEEDOR = 0 OR COM.IDX_PROVEEDOR = @IDX_PROVEEDOR) AND
(@FECHA_INICIAL IS NULL OR FECHA_ABONO > @FECHA_INICIAL) AND
(@FECHA_FINAL IS NULL OR FECHA_ABONO < @FECHA_FINAL)

END
GO

-- =====================================================================================
-- 13. SP_UTILIDADES_ACCIONES — pantalla "Cuadre de Caja" (Caja/postUtilidades).
--     Gaps encontrados tras pruebas del usuario: las sumas de abonos (ventas y
--     compras) y el total de compras NO estaban excluyendo documentos anulados,
--     porque no se unian contra el ANULADO del documento padre (DETALLE_ABONOS_*
--     no tiene su propio flag). Esto afectaba tanto "Resultado 1" (KPIs) como
--     "Resultado 5" (Saldos distribuidos por forma de pago) — el reporte que
--     mostraba el abono de una factura ya anulada.
-- =====================================================================================
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

    -- Abonos recibidos (excluye abonos de facturas anuladas)
    @ganancia_bruta_abonos DECIMAL =
    (
        ISNULL(
            (SELECT SUM(VALOR_ABONADO)
             FROM DETALLE_ABONOS_VENTAS
             WHERE @fecha_inicial <= FECHA_ABONO AND @fecha_final >= FECHA_ABONO
               AND IDX_FACTURA IN (SELECT ID_FACTURA FROM FACTURAS WHERE ANULADO IS NULL OR ANULADO <> 1)),   -- ← excluye anuladas
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
    -- NOTA: se usa CREDITO (no IDX_FORMA_PAGO) porque en Comprar el checkbox
    -- "Pago a credito" es independiente del dropdown "Forma de pago".
    @egresos_compras DECIMAL =
    (
        ISNULL(
            (
                SELECT ISNULL(SUM(COSTO_TOTAL), 0)
                     + ISNULL((
                           SELECT SUM(PAGO_INICIAL)
                           FROM COMPRAS
                           WHERE CREDITO = 1
                             AND @fecha_inicial <= FECHA_COMPRA AND @fecha_final >= FECHA_COMPRA
                             AND (ANULADO IS NULL OR ANULADO <> 1)   -- ← excluye anuladas
                       ), 0)
                FROM COMPRAS
                WHERE @fecha_inicial <= FECHA_COMPRA AND @fecha_final >= FECHA_COMPRA
                  AND (CREDITO IS NULL OR CREDITO <> 1)
                  AND (ANULADO IS NULL OR ANULADO <> 1)              -- ← excluye anuladas
            ),
        0)
    ),
    @egresos_abonos_hechos DECIMAL =
    (
        ISNULL(
            (SELECT SUM(VALOR_ABONADO)
             FROM DETALLE_ABONOS_COMPRAS
             WHERE @fecha_inicial <= FECHA_ABONO AND @fecha_final >= FECHA_ABONO
               AND IDX_COMPRA IN (SELECT ID_COMPRA FROM COMPRAS WHERE ANULADO IS NULL OR ANULADO <> 1)),   -- ← excluye anuladas
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
                 SELECT SUM(GRAMAJE_DEL_PRODUCTO * COSTO_X_UNIDAD) AS total_por_producto
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
        P.GRAMAJE_DEL_PRODUCTO        AS disponible,
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

    -- Resultado 5: Cuadre por forma de pago (excluye documentos anulados en todas las CTEs)
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
          AND (ANULADO IS NULL OR ANULADO <> 1)   -- ← excluye anuladas
        GROUP BY IDX_FORMA_PAGO_INICIAL
    ),
    ABONOS_VENTAS AS (
        SELECT IDX_FORMA_PAGO, SUM(VALOR_ABONADO) AS total_abonos_ventas
        FROM DETALLE_ABONOS_VENTAS
        WHERE @fecha_inicial <= FECHA_ABONO AND @fecha_final >= FECHA_ABONO
          AND IDX_FACTURA IN (SELECT ID_FACTURA FROM FACTURAS WHERE ANULADO IS NULL OR ANULADO <> 1)   -- ← excluye anuladas
        GROUP BY IDX_FORMA_PAGO
    ),
    COMPRAS_HECHAS AS (
        -- Solo compras NO a credito: el efecto de caja de una compra a credito
        -- ya se captura por separado via PAGOS_INICIALES_HECHOS (el abono inicial).
        SELECT IDX_FORMA_PAGO, SUM(COSTO_TOTAL) AS total_compras
        FROM COMPRAS
        WHERE @fecha_inicial <= FECHA_COMPRA AND @fecha_final >= FECHA_COMPRA
          AND (ANULADO IS NULL OR ANULADO <> 1)   -- ← excluye anuladas
          AND (CREDITO IS NULL OR CREDITO <> 1)   -- ← excluye compras a credito
        GROUP BY IDX_FORMA_PAGO
    ),
    ABONOS_COMPRAS AS (
        SELECT IDX_FORMA_PAGO, SUM(VALOR_ABONADO) AS total_abonos_compras
        FROM DETALLE_ABONOS_COMPRAS
        WHERE @fecha_inicial <= FECHA_ABONO AND @fecha_final >= FECHA_ABONO
          AND IDX_COMPRA IN (SELECT ID_COMPRA FROM COMPRAS WHERE ANULADO IS NULL OR ANULADO <> 1)   -- ← excluye anuladas
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

-- =====================================================================================
-- 14. SP_BALANCE_DIARIO_IMPRIMIBLE — "Imprimir Balance" / "Exportar Excel" en la
--     pantalla de Cuadre de Caja (Reportes/balance-diario). No filtraba ANULADO
--     en absoluto (ni facturas, ni compras, ni abonos, ni productos vendidos).
-- =====================================================================================
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
    -- Resultado 1: Ventas (Facturas) del rango (excluye anuladas)
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
      AND (F.ANULADO IS NULL OR F.ANULADO <> 1)   -- ← excluye anuladas
    ORDER BY F.FECHA_VENTA;

    -- -------------------------------------------------------
    -- Resultado 2: Compras del rango (excluye anuladas)
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
      AND (C.ANULADO IS NULL OR C.ANULADO <> 1)   -- ← excluye anuladas
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
    -- Resultado 4: Abonos recibidos de clientes (excluye abonos de facturas anuladas)
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
    INNER JOIN FACTURAS         FAC ON DAV.IDX_FACTURA         = FAC.ID_FACTURA
    WHERE DAV.FECHA_ABONO BETWEEN @fecha_inicio AND @fecha_fin
      AND (FAC.ANULADO IS NULL OR FAC.ANULADO <> 1)   -- ← excluye anuladas
    ORDER BY DAV.FECHA_ABONO;

    -- -------------------------------------------------------
    -- Resultado 5: Abonos pagados a proveedores (excluye abonos de compras anuladas)
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
      AND (C.ANULADO IS NULL OR C.ANULADO <> 1)   -- ← excluye anuladas
    ORDER BY DAC.FECHA_ABONO;

    -- -------------------------------------------------------
    -- Resultado 6: Resumen de productos vendidos en el rango (excluye anuladas)
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
      AND (F.ANULADO IS NULL OR F.ANULADO <> 1)   -- ← excluye anuladas
    GROUP BY P.PRODUCT_ID, P.CODIGO_BARRAS, P.PRODUCTO, P.COSTO_X_UNIDAD
    ORDER BY SUM(VP.QUANTITY) DESC;

END
GO

-- =====================================================================================
-- 15. InsertarCompraMasiva — CORRECCION DE BUG PREEXISTENTE (no introducido por la
--     funcionalidad de anular): la actualizacion de PROVEEDORES.SALDO_PENDIENTE se
--     ejecutaba SIN condicionar a que la compra fuera a credito. Resultado: CUALQUIER
--     compra (incluida una compra 100% en efectivo) sumaba su total completo como
--     deuda al proveedor. Reportado por el usuario: "Compre en efectivo... aparece
--     que debo".
--     Se corrige: (a) se persiste @credito en la nueva columna COMPRAS.CREDITO,
--     (b) el UPDATE a PROVEEDORES.SALDO_PENDIENTE ahora solo ocurre si @credito = 1.
-- =====================================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[InsertarCompraMasiva]
    @usuario DECIMAL,
	@idx_forma_pago DECIMAL,
    @proveedorId DECIMAL,
    @credito BIT,
    @pagoInicial DECIMAL(18,2) = 0,
    @fpagoInicial DECIMAL(18,0) = 0,
    @cuerpoCompras CuerpoCompraTVP READONLY
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @idCompra INT;
    DECLARE @total DECIMAL(18, 2) = 0;
	DECLARE @caja numeric(18,0) = (select top 1 ID_CAJA from CAJA where IDX_USUARIO = @usuario and FECHA_CIERRE_CAJA IS NULL);
	DECLARE @ponderado bit = (SELECT TOP 1 ISNULL(BIT_VALOR_PRODUCTO_PONDERADO,0)  AS BIT_VALOR_PRODUCTO_PONDERADO  FROM CONFIGURACIONES)
	DECLARE @porcentaje_ganancia numeric(10,2) = (SELECT TOP 1 ISNULL(PORCENTAJE_GANANCIA,0) as PORCENTAJE_GANANCIA FROM CONFIGURACIONES)

    INSERT INTO COMPRAS(FECHA_COMPRA, IDX_USUARIO_COMPRADOR, IDX_PROVEEDOR, COSTO_TOTAL, IDX_FORMA_PAGO, PAGO_INICIAL, IDX_CAJA, VALOR_PAGADO, IDX_FORMA_PAGO_INICIAL, CREDITO)
    VALUES (GETDATE(), @usuario, @proveedorId, 0, @idx_forma_pago, @pagoInicial, @caja, 0, @fpagoInicial, @credito);

    SET @idCompra = SCOPE_IDENTITY();

    -- Detalles de productos existentes o gastos
    INSERT INTO COMPRAS_DETALLES(IDX_COMPRA, IDX_PRODUCTO, IDX_ACTIVO, COSTO, CANTIDAD, COMENTARIO_PRODUCTO,GRAMAJE_COMPRADO)
    SELECT
        @idCompra,
        CASE
            WHEN existente = 1 THEN producto
            ELSE NULL
        END AS IdxProducto,
        NULL,
        costoUnidad * cantidad,
        cantidad,
        CASE
            WHEN categoriaNombre = 'Gasto' THEN 'Gasto'
            ELSE NULL
        END,
		gramaje_total
    FROM @cuerpoCompras
    WHERE existente = 1 OR categoriaNombre = 'Gasto';

    -- Actualizar productos existentes (Cantidad y CostoXUnidad con promedio ponderado)


IF(@ponderado = 1)
	BEGIN
	;WITH CTE_Compras AS (
    SELECT 
        producto,
        SUM(cantidad) AS cantidadTotal,
        SUM(cantidad * costoUnidad) AS importeTotal,
		gramaje_total
    FROM @cuerpoCompras
    GROUP BY producto, gramaje_total
	)
		UPDATE p
		SET 
		    p.COSTO_X_UNIDAD = 
		        CASE 
		            WHEN (p.GRAMAJE_DEL_PRODUCTO + c.cantidadTotal) = 0 THEN 0
		            ELSE ((p.GRAMAJE_DEL_PRODUCTO * p.COSTO_X_UNIDAD) + c.importeTotal)  / (p.GRAMAJE_DEL_PRODUCTO + c.cantidadTotal)
		        END,
		    p.QUANTITY = p.QUANTITY + c.cantidadTotal,
		    p.ESTADOS = 1,
			p.GRAMAJE_DEL_PRODUCTO = (ISNULL(p.GRAMAJE_DEL_PRODUCTO,0) + ISNULL(c.gramaje_total,0))
		FROM PRODUCTOS p
		INNER JOIN CTE_Compras c ON p.PRODUCT_ID = c.producto;

	END
ELSE
	BEGIN
	;WITH CTE_Compras AS (
    SELECT
        producto,
        SUM(cantidad) AS cantidadTotal,
        SUM(cantidad * costoUnidad) AS importeTotal,
		gramaje_total
    FROM @cuerpoCompras
    GROUP BY producto, gramaje_total
	)

	UPDATE p
		SET 
		    p.COSTO_X_UNIDAD = (c.importeTotal / c.cantidadTotal) + ((c.importeTotal / c.cantidadTotal) * @porcentaje_ganancia),
		    p.QUANTITY = p.QUANTITY + c.cantidadTotal,
		    p.ESTADOS = 1,
			p.GRAMAJE_DEL_PRODUCTO = (ISNULL(p.GRAMAJE_DEL_PRODUCTO,0) + ISNULL(c.gramaje_total,0))
		FROM PRODUCTOS p
		INNER JOIN CTE_Compras c ON p.PRODUCT_ID = c.producto;

	END

    -- Insertar nuevos productos
	IF(@ponderado = 1)
		BEGIN
				INSERT INTO PRODUCTOS(PRODUCTO, COSTO_X_UNIDAD, IDX_CATEGORIA, QUANTITY, ESTADOS, IDX_PROVEEDOR, CODIGO_BARRAS, IDX_TIPO_MEDIDA, IDX_MEDIDA, IDX_TIPO_GRAMAJE, GRAMAJE, GRAMAJE_DEL_PRODUCTO)
				SELECT
					productoNombre,
					costoUnidad,
					categoriaId,
					cantidad,
					1,
					@proveedorId,

					codigoProducto ,

					tipoMedida	   ,
					medidaPejase   ,

					gramajeProducto,
					gramajeUnidad  ,
					gramaje_total

				FROM @cuerpoCompras
				WHERE existente = 0 AND categoriaNombre NOT IN ('Activo', 'Gasto');


		END
	ELSE
		BEGIN
			INSERT INTO PRODUCTOS(PRODUCTO, COSTO_X_UNIDAD, IDX_CATEGORIA, QUANTITY, ESTADOS, IDX_PROVEEDOR, CODIGO_BARRAS, IDX_TIPO_MEDIDA, IDX_MEDIDA, IDX_TIPO_GRAMAJE, GRAMAJE, GRAMAJE_DEL_PRODUCTO)
			SELECT
			    productoNombre,
			    (costoUnidad * @porcentaje_ganancia) + costoUnidad,
			    categoriaId,
			    cantidad,
			    1,
				@proveedorId,

				codigoProducto ,

				tipoMedida	   ,
				medidaPejase   ,

				gramajeProducto,
				gramajeUnidad  ,
				gramaje_total

			FROM @cuerpoCompras
			WHERE existente = 0 AND categoriaNombre NOT IN ('Activo', 'Gasto');
		END

    -- Insertar nuevos activos
    INSERT INTO ACTIVOS(ACTIVO, COSTO_X_UNIDAD, Quantity, Estados)
    SELECT
        productoNombre,
        costoUnidad,
        cantidad,
        1
    FROM @cuerpoCompras
    WHERE existente = 0 AND categoriaNombre = 'Activo';

    -- Insertar detalles de nuevos productos
    INSERT INTO COMPRAS_DETALLES(IDX_COMPRA, IDX_PRODUCTO, IDX_ACTIVO, Costo, Cantidad, GRAMAJE_COMPRADO)
    SELECT
        @idCompra,
        p.PRODUCT_ID,
        NULL,
        cc.costoUnidad * cc.cantidad,
        cc.cantidad,
		cc.gramaje_total
    FROM @cuerpoCompras cc
    INNER JOIN PRODUCTOS p ON cc.existente = 0 AND cc.categoriaNombre NOT IN ('Activo', 'Gasto') AND p.PRODUCTO = cc.productoNombre;

    -- Insertar detalles de nuevos activos
    INSERT INTO COMPRAS_DETALLES(IDX_COMPRA, IDX_PRODUCTO, IDX_ACTIVO, Costo, Cantidad)
    SELECT
        @idCompra,
        NULL,
        a.ID_ACTIVO,
        cc.costoUnidad * cc.cantidad,
        cc.cantidad
    FROM @cuerpoCompras cc
    INNER JOIN ACTIVOS a ON cc.existente = 0 AND cc.categoriaNombre = 'Activo' AND a.ACTIVO = cc.productoNombre;

    -- Calcular total
    SELECT @total = SUM(c.Costo)
    FROM COMPRAS_DETALLES c
    WHERE c.IDX_COMPRA = @idCompra;

    -- Actualizar total en COMPRAS
    UPDATE COMPRAS
    SET COSTO_TOTAL = @total,
	VALOR_PAGADO = CASE @credito WHEN 1 THEN @pagoInicial ELSE @total END
    WHERE ID_COMPRA = @idCompra;

	-- CORREGIDO: antes esto se ejecutaba siempre, sumando el total completo de
	-- CUALQUIER compra (incluso en efectivo) como deuda al proveedor. Ahora solo
	-- se acumula deuda cuando la compra realmente es a credito.
	IF (@credito = 1)
	BEGIN
		DECLARE @SALDO_PENDIENTE_PROVEEDOR DECIMAL = (SELECT TOP 1 ISNULL(SALDO_PENDIENTE,0) FROM PROVEEDORES WHERE ID_PROVEEDOR = @proveedorId)

		UPDATE PROVEEDORES
		SET SALDO_PENDIENTE = @SALDO_PENDIENTE_PROVEEDOR + (@total - @pagoInicial)
		WHERE ID_PROVEEDOR = @proveedorId
	END

END
GO

-- =====================================================================================
-- 16. CORRECCION MANUAL DE DATOS DE PRUEBA (opcional, ejecutar solo si aplica)
--     El bug de la seccion 15 ya afecto datos existentes: cualquier compra creada
--     ANTES de este fix pudo haber sumado deuda indebida a su proveedor, sin forma
--     de saber retroactivamente cuales eran realmente a credito (CREDITO no existia).
--     Para "Prueba proveedor" (u otro proveedor de prueba puntual), si se sabe que
--     NO deberia tener deuda pendiente, se puede corregir manualmente asi:
--
--     UPDATE PROVEEDORES SET SALDO_PENDIENTE = 0 WHERE RAZON_SOCIAL = 'Prueba proveedor';
--
--     No se incluye como parte automatica de esta migracion porque podria borrar
--     deuda real de proveedores que si tienen compras a credito legitimas pendientes.
--     Revisar caso por caso antes de ejecutar.
-- =====================================================================================
