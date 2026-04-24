using CORE.MMms.DTOs;
using CORE.MMms.Interfaces;
using INFRA.MMms.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System.Data;

namespace INFRA.MMms.Repository
{
    public class DianConfigRepo : IDianConfig
    {
        private readonly MotoMastersDbContext _context;

        public DianConfigRepo(MotoMastersDbContext context) => _context = context;

        private SqlConnection Conn() =>
            new(_context.Database.GetDbConnection().ConnectionString);

        private DataTable Fill(string sp, Action<SqlCommand> configure)
        {
            var dt = new DataTable();
            using var conn = Conn();
            using var cmd  = new SqlCommand(sp, conn) { CommandType = CommandType.StoredProcedure };
            configure(cmd);
            new SqlDataAdapter(cmd).Fill(dt);
            return dt;
        }

        private void Execute(string sp, Action<SqlCommand> configure)
        {
            using var conn = Conn();
            using var cmd  = new SqlCommand(sp, conn) { CommandType = CommandType.StoredProcedure };
            configure(cmd);
            conn.Open();
            cmd.ExecuteNonQuery();
        }

        // ── Company ──────────────────────────────────────────────
        public DataTable GetEmpresa() =>
            Fill("SP_DIAN_EMPRESA_CONSULTAR", _ => { });

        public void ActualizarEmpresa(DianEmpresaDto dto) =>
            Execute("SP_DIAN_EMPRESA_ACTUALIZAR", cmd =>
            {
                cmd.Parameters.Add("@nombre_comercial",                   SqlDbType.VarChar,  200).Value = (object?)dto.NombreComercial                 ?? DBNull.Value;
                cmd.Parameters.Add("@digito_verificacion",                SqlDbType.VarChar,    2).Value = (object?)dto.DigitoVerificacion               ?? DBNull.Value;
                cmd.Parameters.Add("@municipio_dian",                     SqlDbType.VarChar,   10).Value = (object?)dto.MunicipioDian                    ?? DBNull.Value;
                cmd.Parameters.Add("@departamento_dian",                  SqlDbType.VarChar,   10).Value = (object?)dto.DepartamentoDian                 ?? DBNull.Value;
                cmd.Parameters.Add("@codigo_postal",                      SqlDbType.VarChar,   10).Value = (object?)dto.CodigoPostal                     ?? DBNull.Value;
                cmd.Parameters.Add("@idx_tipo_documento_empresa",         SqlDbType.Int).Value           = (object?)dto.IdxTipoDocumentoEmpresa          ?? DBNull.Value;
                cmd.Parameters.Add("@idx_regimen_tributario_empresa",     SqlDbType.Int).Value           = (object?)dto.IdxRegimenTributarioEmpresa      ?? DBNull.Value;
                cmd.Parameters.Add("@idx_responsabilidad_fiscal_empresa", SqlDbType.Int).Value           = (object?)dto.IdxResponsabilidadFiscalEmpresa  ?? DBNull.Value;
                cmd.Parameters.Add("@ambiente_dian",                      SqlDbType.Int).Value           = dto.AmbienteDian;
            });

        // ── Resolutions ──────────────────────────────────────────
        public DataTable GetResoluciones() =>
            Fill("SP_DIAN_RESOLUCIONES_LISTAR", _ => { });

        public void CrearResolucion(DianResolucionDto dto) =>
            Execute("SP_DIAN_RESOLUCION_CREAR", cmd =>
            {
                cmd.Parameters.Add("@numero_resolucion", SqlDbType.VarChar,  20).Value = dto.NumeroResolucion;
                cmd.Parameters.Add("@fecha_resolucion",  SqlDbType.Date).Value          = dto.FechaResolucion;
                cmd.Parameters.Add("@fecha_inicio",      SqlDbType.Date).Value          = dto.FechaInicio;
                cmd.Parameters.Add("@fecha_fin",         SqlDbType.Date).Value          = dto.FechaFin;
                cmd.Parameters.Add("@prefijo",           SqlDbType.VarChar,  10).Value  = (object?)dto.Prefijo ?? DBNull.Value;
                cmd.Parameters.Add("@rango_inicio",      SqlDbType.Decimal).Value       = dto.RangoInicio;
                cmd.Parameters.Add("@rango_fin",         SqlDbType.Decimal).Value       = dto.RangoFin;
                cmd.Parameters.Add("@clave_tecnica",     SqlDbType.VarChar, 200).Value  = dto.ClaveTecnica;
                cmd.Parameters.Add("@tipo",              SqlDbType.VarChar,   2).Value  = dto.Tipo;
            });

        public void ActivarResolucion(long id, string tipo) =>
            Execute("SP_DIAN_RESOLUCION_ACTIVAR", cmd =>
            {
                cmd.Parameters.Add("@id_resolucion", SqlDbType.Decimal).Value = id;
                cmd.Parameters.Add("@tipo",          SqlDbType.VarChar, 2).Value = tipo;
            });

        // ── Catalog ──────────────────────────────────────────────
        public DataTable GetTiposIva() =>
            Fill("SP_DIAN_TIPOS_IVA", _ => { });

        // ── Product ──────────────────────────────────────────────
        public DataTable GetProductoCampos(long idProducto) =>
            Fill("SP_DIAN_PRODUCTO_CAMPOS", cmd =>
                cmd.Parameters.Add("@id_producto", SqlDbType.Decimal).Value = idProducto);

        public void ActualizarProductoCampos(long idProducto, DianProductoCamposDto dto) =>
            Execute("SP_DIAN_ACTUALIZAR_PRODUCTO", cmd =>
            {
                cmd.Parameters.Add("@id_producto",   SqlDbType.Decimal).Value        = idProducto;
                cmd.Parameters.Add("@codigo_unspsc", SqlDbType.VarChar, 20).Value    = (object?)dto.CodigoUnspsc ?? DBNull.Value;
                cmd.Parameters.Add("@idx_tipo_iva",  SqlDbType.Int).Value             = (object?)dto.IdxTipoIva   ?? DBNull.Value;
            });

        // ── Client ───────────────────────────────────────────────
        public DataTable GetClienteCampos(long idCliente) =>
            Fill("SP_DIAN_CLIENTE_CAMPOS", cmd =>
                cmd.Parameters.Add("@id_cliente", SqlDbType.Decimal).Value = idCliente);

        public void ActualizarClienteCampos(long idCliente, DianClienteCamposDto dto) =>
            Execute("SP_DIAN_ACTUALIZAR_CLIENTE", cmd =>
            {
                cmd.Parameters.Add("@id_cliente",          SqlDbType.Decimal).Value     = idCliente;
                cmd.Parameters.Add("@municipio_dian",      SqlDbType.VarChar, 10).Value = (object?)dto.MunicipioDian      ?? DBNull.Value;
                cmd.Parameters.Add("@codigo_postal",       SqlDbType.VarChar, 10).Value = (object?)dto.CodigoPostal       ?? DBNull.Value;
                cmd.Parameters.Add("@digito_verificacion", SqlDbType.VarChar,  2).Value = (object?)dto.DigitoVerificacion ?? DBNull.Value;
            });

        // ── Payment ──────────────────────────────────────────────
        public DataTable GetPagoCampo(long idPago) =>
            Fill("SP_DIAN_PAGO_CAMPOS", cmd =>
                cmd.Parameters.Add("@id_forma_pago", SqlDbType.Decimal).Value = idPago);

        public void ActualizarPagoCampo(long idPago, string? codigoMedioPago) =>
            Execute("SP_DIAN_ACTUALIZAR_PAGO", cmd =>
            {
                cmd.Parameters.Add("@id_forma_pago",          SqlDbType.Decimal).Value  = idPago;
                cmd.Parameters.Add("@codigo_medio_pago_dian", SqlDbType.VarChar, 3).Value = (object?)codigoMedioPago ?? DBNull.Value;
            });
    }
}
