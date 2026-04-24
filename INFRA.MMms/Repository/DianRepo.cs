using CORE.MMms.DTOs;
using CORE.MMms.Interfaces;
using INFRA.MMms.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System.Data;

namespace INFRA.MMms.Repository
{
    public class DianRepo : IDian
    {
        private readonly MotoMastersDbContext _context;

        public DianRepo(MotoMastersDbContext context)
        {
            _context = context;
        }

        public DataSet GetDatosFactura(long idFactura)
        {
            var result = new DataSet();

            using var connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString);
            using var command = new SqlCommand("SP_DIAN_DATOS_FACTURA", connection)
            {
                CommandType = CommandType.StoredProcedure
            };
            command.Parameters.Add("@id_factura", SqlDbType.Decimal).Value = idFactura;

            var adapter = new SqlDataAdapter(command);
            adapter.Fill(result);

            return result;
        }

        public DataSet ActualizarEstado(long idFactura, string? cufe, string? estadoDian,
            string? qrDian, string? xmlDian, string? notasDian)
        {
            var result = new DataSet();

            using var connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString);
            using var command = new SqlCommand("SP_DIAN_ACTUALIZAR_ESTADO", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.Add("@id_factura", SqlDbType.Decimal).Value = idFactura;
            command.Parameters.Add("@cufe",        SqlDbType.VarChar, 1000).Value = (object?)cufe        ?? DBNull.Value;
            command.Parameters.Add("@estado_dian", SqlDbType.VarChar,   20).Value = (object?)estadoDian  ?? DBNull.Value;
            command.Parameters.Add("@qr_dian",     SqlDbType.VarChar,  500).Value = (object?)qrDian      ?? DBNull.Value;
            command.Parameters.Add("@xml_dian",    SqlDbType.VarChar,   -1).Value = (object?)xmlDian     ?? DBNull.Value;
            command.Parameters.Add("@notas_dian",  SqlDbType.VarChar, 1000).Value = (object?)notasDian   ?? DBNull.Value;

            var adapter = new SqlDataAdapter(command);
            adapter.Fill(result);

            return result;
        }

        public DianXmlPendienteDto? GetXmlPendiente(long idFactura)
        {
            using var connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString);
            using var command = new SqlCommand("SP_DIAN_OBTENER_XML", connection)
            {
                CommandType = CommandType.StoredProcedure
            };
            command.Parameters.Add("@id_factura", SqlDbType.Decimal).Value = idFactura;

            connection.Open();
            using var reader = command.ExecuteReader();

            if (!reader.Read()) return null;

            return new DianXmlPendienteDto
            {
                XmlFirmado   = reader["XML_DIAN"]?.ToString()    ?? string.Empty,
                EstadoDian   = reader["estado_dian"]?.ToString() ?? string.Empty,
                TrackId      = reader["TRACK_ID_DIAN"] == DBNull.Value
                                   ? null
                                   : reader["TRACK_ID_DIAN"].ToString(),
                ZipKey       = reader["zip_key"]?.ToString()     ?? string.Empty,
                AmbienteDian = reader["ambiente_dian"] == DBNull.Value
                                   ? 2
                                   : Convert.ToInt32(reader["ambiente_dian"])
            };
        }

        public void ActualizarTrackId(long idFactura, string trackId)
        {
            using var connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString);
            using var command = new SqlCommand("SP_DIAN_GUARDAR_TRACK", connection)
            {
                CommandType = CommandType.StoredProcedure
            };
            command.Parameters.Add("@id_factura", SqlDbType.Decimal).Value    = idFactura;
            command.Parameters.Add("@track_id",   SqlDbType.VarChar, 100).Value = trackId;

            connection.Open();
            command.ExecuteNonQuery();
        }

        public DataTable GetReporte(string? estadoDian, DateTime? fechaInicio, DateTime? fechaFin)
        {
            var result = new DataTable();

            using var connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString);
            using var command = new SqlCommand("SP_DIAN_REPORTE_ESTADOS", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.Add("@estado_dian",  SqlDbType.VarChar, 20).Value =
                string.IsNullOrWhiteSpace(estadoDian) ? DBNull.Value : (object)estadoDian;
            command.Parameters.Add("@fecha_inicio", SqlDbType.Date).Value =
                fechaInicio.HasValue ? (object)fechaInicio.Value : DBNull.Value;
            command.Parameters.Add("@fecha_fin",    SqlDbType.Date).Value =
                fechaFin.HasValue ? (object)fechaFin.Value : DBNull.Value;

            var adapter = new SqlDataAdapter(command);
            adapter.Fill(result);

            return result;
        }
    }
}
