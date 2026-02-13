using CORE.MMms.DTOs;
using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using INFRA.MMms.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using System.Data;
using System.Data;
using System.Data.SqlClient;

namespace INFRA.MMms.Repository
{
    public class GastosRepo : IGastos
    {
        private readonly MotoMastersDbContext _context;
        public GastosRepo(MotoMastersDbContext context)
        {
            _context = context;
        }

        public DataTable Post(GastoDto MMD)
        {
            return GastosAcciones(MMD, "INSERT");
        }

        public DataTable Update(GastoDto MMD)
        {
            return GastosAcciones(MMD, "UPDATE");
        }

        public DataTable SelectGastos()
        {
            DataTable productos = GastosAcciones(new GastoDto(), "SELECT");
            return productos;
        }

        private DataTable GastosAcciones(GastoDto dto, string operacion)
        {
            DataTable result = new DataTable();

            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_GASTOS_ACCIONES", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    command.Parameters.Add("@OPERACION", SqlDbType.VarChar, 100).Value = operacion;

                    if (dto.iD_GASTO.HasValue)
                        command.Parameters.Add("@ID_GASTO", SqlDbType.Int).Value = dto.iD_GASTO.Value;

                    if (dto.nombre != null)
                        command.Parameters.Add("@NOMBRE", SqlDbType.NVarChar, 100).Value = dto.nombre;

                    if (dto.costo.HasValue)
                        command.Parameters.Add("@COSTO", SqlDbType.Decimal).Value = dto.costo.Value;

                    if (dto.cantidad.HasValue)
                        command.Parameters.Add("@CANTIDAD", SqlDbType.Int).Value = dto.cantidad.Value;

                    if (dto.descripcion != null)
                        command.Parameters.Add("@DESCRIPCION", SqlDbType.NVarChar, 200).Value = dto.descripcion;

                    if (dto.eS_FIJO.HasValue)
                        command.Parameters.Add("@ES_FIJO", SqlDbType.Bit).Value = dto.eS_FIJO.Value;

                    if (dto.activo.HasValue)
                        command.Parameters.Add("@ACTIVO", SqlDbType.Bit).Value = dto.activo.Value;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(result);
                }
            }

            return result;
        }


    }
}
