using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using INFRA.MMms.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System.Data;

namespace INFRA.MMms.Repository
{
    public class CajaRepo : ICaja
    {
        private readonly MotoMastersDbContext _context;
        public CajaRepo(MotoMastersDbContext context)
        {
            _context = context;
        }



        public async Task<long> AbrirCaja(long idUsuario)
        {
            using var connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString);
            using var command = new SqlCommand("CAJA_ACCIONES", connection);

            command.CommandType = CommandType.StoredProcedure;

            command.Parameters.AddWithValue("@OPERACION", "ABRIR_CAJA");
            command.Parameters.AddWithValue("@ID_USUARIO", idUsuario);

            var idCajaParam = new SqlParameter("@ID_CAJA", SqlDbType.Decimal)
            {
                Precision = 18,
                Scale = 0,
                Direction = ParameterDirection.Output
            };
            command.Parameters.Add(idCajaParam);

            var tvpParam = command.Parameters.AddWithValue("@cuerpoSaldosCaja", CreateEmptyCajaTable());
            tvpParam.SqlDbType = SqlDbType.Structured;
            tvpParam.TypeName = "CuerpoSaldosCajaTVP";

            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();

            return Convert.ToInt64(idCajaParam.Value);
        }

        public async Task CerrarCaja(long idUsuario, DataTable saldosCierre)
        {
            using var connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString);
            using var command = new SqlCommand("CAJA_ACCIONES", connection);

            command.CommandType = CommandType.StoredProcedure;

            command.Parameters.AddWithValue("@OPERACION", "CERRAR_CAJA");
            command.Parameters.AddWithValue("@ID_USUARIO", idUsuario);

            var idCajaParam = new SqlParameter("@ID_CAJA", SqlDbType.Decimal)
            {
                Precision = 18,
                Scale = 0,
                Direction = ParameterDirection.Output
            };
            command.Parameters.Add(idCajaParam);

            var tvpParam = command.Parameters.AddWithValue("@cuerpoSaldosCaja", saldosCierre);
            tvpParam.SqlDbType = SqlDbType.Structured;
            tvpParam.TypeName = "CuerpoSaldosCajaTVP";

            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();
        }

        public async Task<bool> EstadoCaja(long idUsuario)
        {
            using var connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString);
            using var command = new SqlCommand("CAJA_ACCIONES", connection);

            command.CommandType = CommandType.StoredProcedure;

            command.Parameters.AddWithValue("@OPERACION", "ESTADO_CAJA");
            command.Parameters.AddWithValue("@ID_USUARIO", idUsuario);

            var idCajaParam = new SqlParameter("@ID_CAJA", SqlDbType.Decimal)
            {
                Precision = 18,
                Scale = 0,
                Direction = ParameterDirection.Output
            };
            command.Parameters.Add(idCajaParam);

            var tvpParam = command.Parameters.AddWithValue("@cuerpoSaldosCaja", CreateEmptyCajaTable());
            tvpParam.SqlDbType = SqlDbType.Structured;
            tvpParam.TypeName = "CuerpoSaldosCajaTVP";

            await connection.OpenAsync();

            using var reader = await command.ExecuteReaderAsync();

            if (await reader.ReadAsync())
                return reader.GetInt32(0) == 1;

            return false;
        }

        public async Task VerificacionCaja(long idUsuario)
        {
            using var connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString);
            using var command = new SqlCommand("CAJA_ACCIONES", connection);

            command.CommandType = CommandType.StoredProcedure;

            command.Parameters.AddWithValue("@OPERACION", "VERIFICACION");
            command.Parameters.AddWithValue("@ID_USUARIO", idUsuario);

            var idCajaParam = new SqlParameter("@ID_CAJA", SqlDbType.Decimal)
            {
                Precision = 18,
                Scale = 0,
                Direction = ParameterDirection.Output
            };
            command.Parameters.Add(idCajaParam);

            var tvpParam = command.Parameters.AddWithValue("@cuerpoSaldosCaja", CreateEmptyCajaTable());
            tvpParam.SqlDbType = SqlDbType.Structured;
            tvpParam.TypeName = "CuerpoSaldosCajaTVP";

            await connection.OpenAsync();

            using var reader = await command.ExecuteReaderAsync();

            // Result 1 → Facturas
            if (await reader.ReadAsync())
            {
                var facturas = reader.GetInt32(0);
                var totalFacturas = reader.GetDecimal(1);
            }

            // Siguiente result set
            await reader.NextResultAsync();

            // Result 2 → Compras
            if (await reader.ReadAsync())
            {
                var compras = reader.GetInt32(0);
                var totalCompras = reader.GetDecimal(1);
            }

            await reader.NextResultAsync();

            // Result 3 → Caja en número
            if (await reader.ReadAsync())
            {
                var compras = reader.GetInt32(0);
                var totalCompras = reader.GetDecimal(1);
            }

            // Puedes seguir avanzando con NextResultAsync()
        }

        private DataTable CreateEmptyCajaTable()
        {
            var table = new DataTable();
            table.Columns.Add("IDX_DENOMINACION", typeof(long));
            table.Columns.Add("SALDO", typeof(decimal));
            return table;
        }


    }
}
