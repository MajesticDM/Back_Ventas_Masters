-- ============================================================
-- DIAN Configuration SPs — Phase 4 Part B
-- Run after sp_dian_fase3.sql
-- ============================================================

-- ─── 1. Company DIAN fields ─────────────────────────────────

CREATE OR ALTER PROCEDURE SP_DIAN_EMPRESA_CONSULTAR
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

CREATE OR ALTER PROCEDURE SP_DIAN_EMPRESA_ACTUALIZAR
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
        NOMBRE_COMERCIAL                    = ISNULL(@nombre_comercial,                   NOMBRE_COMERCIAL),
        DIGITO_VERIFICACION                 = ISNULL(@digito_verificacion,                DIGITO_VERIFICACION),
        MUNICIPIO_DIAN                      = ISNULL(@municipio_dian,                     MUNICIPIO_DIAN),
        DEPARTAMENTO_DIAN                   = ISNULL(@departamento_dian,                  DEPARTAMENTO_DIAN),
        CODIGO_POSTAL                       = ISNULL(@codigo_postal,                      CODIGO_POSTAL),
        IDX_TIPO_DOCUMENTO_EMPRESA          = ISNULL(@idx_tipo_documento_empresa,         IDX_TIPO_DOCUMENTO_EMPRESA),
        IDX_REGIMEN_TRIBUTARIO_EMPRESA      = ISNULL(@idx_regimen_tributario_empresa,     IDX_REGIMEN_TRIBUTARIO_EMPRESA),
        IDX_RESPONSABILIDAD_FISCAL_EMPRESA  = ISNULL(@idx_responsabilidad_fiscal_empresa, IDX_RESPONSABILIDAD_FISCAL_EMPRESA),
        AMBIENTE_DIAN                       = ISNULL(@ambiente_dian,                      AMBIENTE_DIAN);
END
GO

-- ─── 2. Resolutions ─────────────────────────────────────────

CREATE OR ALTER PROCEDURE SP_DIAN_RESOLUCIONES_LISTAR
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        ID_RESOLUCION,
        NUMERO_RESOLUCION,
        FECHA_RESOLUCION,
        FECHA_INICIO_VIGENCIA,
        FECHA_FIN_VIGENCIA,
        ISNULL(PREFIJO, '') AS PREFIJO,
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

CREATE OR ALTER PROCEDURE SP_DIAN_RESOLUCION_CREAR
    @numero_resolucion    VARCHAR(20),
    @fecha_resolucion     DATE,
    @fecha_inicio         DATE,
    @fecha_fin            DATE,
    @prefijo              VARCHAR(10) = NULL,
    @rango_inicio         NUMERIC,
    @rango_fin            NUMERIC,
    @clave_tecnica        VARCHAR(200),
    @tipo                 VARCHAR(2)  = 'FC'
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

CREATE OR ALTER PROCEDURE SP_DIAN_RESOLUCION_ACTIVAR
    @id_resolucion NUMERIC,
    @tipo          VARCHAR(2) = 'FC'
AS
BEGIN
    SET NOCOUNT ON;
    -- Deactivate all of same type, then activate the target
    UPDATE RESOLUCIONES_DIAN SET ACTIVA = 0 WHERE TIPO = @tipo;
    UPDATE RESOLUCIONES_DIAN SET ACTIVA = 1 WHERE ID_RESOLUCION = @id_resolucion;
END
GO

-- ─── 3. TIPOS_IVA catalog ────────────────────────────────────

CREATE OR ALTER PROCEDURE SP_DIAN_TIPOS_IVA
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ID_TIPO_IVA,
           DESCRIPCION + ' (' + CAST(PORCENTAJE AS VARCHAR) + '%)' AS TIPO_IVA,
           PORCENTAJE,
           CODIGO_TRIBUTO,
           NOMBRE_TRIBUTO
    FROM   TIPOS_IVA
    ORDER  BY ID_TIPO_IVA;
END
GO

-- ─── 4. Product DIAN fields ──────────────────────────────────

CREATE OR ALTER PROCEDURE SP_DIAN_PRODUCTO_CAMPOS
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

CREATE OR ALTER PROCEDURE SP_DIAN_ACTUALIZAR_PRODUCTO
    @id_producto   NUMERIC,
    @codigo_unspsc VARCHAR(20)  = NULL,
    @idx_tipo_iva  INT          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE PRODUCTOS SET
        CODIGO_UNSPSC = ISNULL(@codigo_unspsc, CODIGO_UNSPSC),
        IDX_TIPO_IVA  = ISNULL(@idx_tipo_iva,  IDX_TIPO_IVA)
    WHERE PRODUCT_ID = @id_producto;
END
GO

-- ─── 5. Client DIAN fields ───────────────────────────────────

CREATE OR ALTER PROCEDURE SP_DIAN_CLIENTE_CAMPOS
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

CREATE OR ALTER PROCEDURE SP_DIAN_ACTUALIZAR_CLIENTE
    @id_cliente          NUMERIC,
    @municipio_dian      VARCHAR(10)  = NULL,
    @codigo_postal       VARCHAR(10)  = NULL,
    @digito_verificacion VARCHAR(2)   = NULL
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

-- ─── 6. Payment method DIAN field ────────────────────────────

CREATE OR ALTER PROCEDURE SP_DIAN_PAGO_CAMPOS
    @id_forma_pago NUMERIC
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ISNULL(CODIGO_MEDIO_PAGO_DIAN, '') AS CODIGO_MEDIO_PAGO_DIAN
    FROM   FORMAS_PAGO
    WHERE  ID_FORMA_PAGO = @id_forma_pago;
END
GO

CREATE OR ALTER PROCEDURE SP_DIAN_ACTUALIZAR_PAGO
    @id_forma_pago          NUMERIC,
    @codigo_medio_pago_dian VARCHAR(3)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE FORMAS_PAGO
    SET    CODIGO_MEDIO_PAGO_DIAN = @codigo_medio_pago_dian
    WHERE  ID_FORMA_PAGO = @id_forma_pago;
END
GO
