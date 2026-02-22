using CORE.MMms.DTOs;
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

        public DataSet getInformeCaja(postUtilidades dto)
        {
            return getUtilidades(dto);
        }
        public async void abrirCaja(cajaAperturaCierre dto)
        {
            AbrirCajaUsuario(dto);
        }
        public void cerrarCaja(cajaAperturaCierre dto)
        {
            CerrarCajaUsuario(dto.ID_USUARIO);
        }

        public bool getEstadoCaja(decimal Id)
        {
            return EstadoCaja(Id);
        }

        public DataSet getVerificarCaja(int id_usuario, int id_caja)
        {
            return VerificacionCaja(id_usuario, id_caja);
        }

        public DataTable getTipoMovimientos()
        {
            return GetTipoMovimientos();
        }

        public async  Task<bool> realizarMovimiento(List<RealizarMovimientosDTO> dto)
        {
            return await RealizarMovimientosAsync(dto);
        }

        private async Task<long> AbrirCajaUsuario(cajaAperturaCierre caja)
        {
            using var connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString);
            using var command = new SqlCommand("CAJA_ACCIONES", connection);

            command.CommandType = CommandType.StoredProcedure;

            command.Parameters.AddWithValue("@OPERACION", "ABRIR_CAJA");
            command.Parameters.AddWithValue("@ID_USUARIO", caja.ID_USUARIO);

            var idCajaParam = new SqlParameter("@ID_CAJA", SqlDbType.Decimal)
            {
                Precision = 18,
                Scale = 0,
                Direction = ParameterDirection.Output
            };
            command.Parameters.Add(idCajaParam);

            DataTable saldos = new DataTable();

            saldos.Columns.Add("IDX_DENOMINACION", typeof(int));

            saldos.Columns.Add("SALDO", typeof(decimal));

            for (int i = 0; i < caja.saldos.Count; i++)
            {
                DataRow row = saldos.NewRow();
                row["IDX_DENOMINACION"] = caja.saldos[i].IDX_DENOMINACION;
                row["SALDO"] = caja.saldos[i].SALDO;

                saldos.Rows.Add(row);
            }

            var tvpParam = command.Parameters.AddWithValue("@cuerpoSaldosCaja", saldos);
            tvpParam.SqlDbType = SqlDbType.Structured;
            tvpParam.TypeName = "CuerpoSaldosCajaTVP";

            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();

            return Convert.ToInt64(idCajaParam.Value);
        }

        private async Task CerrarCajaUsuario(decimal idUsuario)
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

            var tvpParam = command.Parameters.AddWithValue("@cuerpoSaldosCaja", CreateEmptyCajaTable());
            tvpParam.SqlDbType = SqlDbType.Structured;
            tvpParam.TypeName = "CuerpoSaldosCajaTVP";

            await connection.OpenAsync();
            await command.ExecuteNonQueryAsync();
        }

        private bool EstadoCaja(decimal idUsuario)
        {
            using var connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString);

            using var command = new SqlCommand("CAJA_ACCIONES", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.Add("@OPERACION", SqlDbType.VarChar, 20)
                   .Value = "ESTADO_CAJA";

            command.Parameters.Add("@ID_USUARIO", SqlDbType.Decimal)
                   .Value = idUsuario;

            var idCajaParam = new SqlParameter("@ID_CAJA", SqlDbType.Decimal)
            {
                Precision = 18,
                Scale = 0,
                Direction = ParameterDirection.Output
            };
            command.Parameters.Add(idCajaParam);

            var tvpParam = command.Parameters.Add("@cuerpoSaldosCaja", SqlDbType.Structured);
            tvpParam.TypeName = "CuerpoSaldosCajaTVP";
            tvpParam.Value = CreateEmptyCajaTable();

            connection.Open();

            var result = command.ExecuteScalar();

            return result != null && Convert.ToInt32(result) == 1;
        }

        private DataSet VerificacionCaja(decimal usuario, int id_caja)
        {
            DataSet result = new DataSet();

            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("CAJA_ACCIONES", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    command.Parameters.Add("@OPERACION", SqlDbType.VarChar, 100).Value = "VERIFICACION";
                    command.Parameters.Add("@ID_USUARIO", SqlDbType.Decimal, 190).Value = usuario;
                    command.Parameters.Add("@ID_CAJA", SqlDbType.Decimal, 190).Value = id_caja == 0 ? null : id_caja;


                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(result);
                }
            }

            return result;
        }

        private DataTable CreateEmptyCajaTable()
        {
            var table = new DataTable();
            table.Columns.Add("IDX_DENOMINACION", typeof(long));
            table.Columns.Add("SALDO", typeof(decimal));
            return table;
        }


        private DataTable GetTipoMovimientos()
        {
            DataTable result = new DataTable();

            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_TIPO_MOVIMIENTOS_ACCIONES", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    command.Parameters.Add("@OPERACION", SqlDbType.VarChar, 10).Value = "SELECT";
                        

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(result);
                }
            }

            return result;
        }

        private async Task<bool> RealizarMovimientosAsync(List<RealizarMovimientosDTO> dto)
        {
            await using var connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString);

            await using var command = new SqlCommand("MOVIMIENTOS_CAJA_ACCIONES", connection);

            command.CommandType = CommandType.StoredProcedure;
            command.Parameters.AddWithValue("@OPERACION", "INSERTAR");

            DataTable saldos = new DataTable();

            saldos.Columns.Add("IDX_USUARIO", typeof(decimal));
            saldos.Columns.Add("IDX_DENOMINACION", typeof(decimal));
            saldos.Columns.Add("IDX_TIPO_MOVIMIENTO", typeof(decimal));
            saldos.Columns.Add("IDX_GASTO", typeof(decimal));
            saldos.Columns.Add("VALOR", typeof(decimal));
            saldos.Columns.Add("DESCRIPCION", typeof(string));

            foreach (var item in dto)
            {
                saldos.Rows.Add(
                    item.IDX_USUARIO,
                    item.IDX_DENOMINACION,
                    item.IDX_TIPO_MOVIMIENTO,
                    item.IDX_GASTO,
                    item.VALOR,
                    item.DESCRIPCION
                );
            }

            var tvpParam = command.Parameters.AddWithValue("@cuerpoMovimientos", saldos);
            tvpParam.SqlDbType = SqlDbType.Structured;
            tvpParam.TypeName = "CuerpoMovimientosCajaTVP";

            await connection.OpenAsync();
            var rowsAffected = await command.ExecuteNonQueryAsync();

            return rowsAffected > 0;
        }

        private DataSet getUtilidades(postUtilidades fechas)    
        {
            DataSet result = new DataSet();

            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_UTILIDADES_ACCIONES", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    command.Parameters.Add("@fecha_inicial", SqlDbType.DateTime).Value = fechas.fecha_inicial;
                    command.Parameters.Add("@fecha_final", SqlDbType.DateTime).Value = fechas.fecha_final;


                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(result);
                }
            }

            return result;
        }
    }
}
