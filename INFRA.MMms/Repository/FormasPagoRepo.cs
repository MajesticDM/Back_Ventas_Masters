using CORE.MMms.DTOs;
using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using INFRA.MMms.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System.Data;

namespace INFRA.MMms.Repository
{
    public class FormasPagoRepo : IFormasPago
    {
        private readonly MotoMastersDbContext _context;
        public FormasPagoRepo(MotoMastersDbContext context)
        {
            _context = context;
        }

        public DataSet GetFormasPago()
        {
            var MMD = FormasPagoAcciones(new FormasPagoDto(), "SELECT");
            return MMD;
        }


        public DataSet Post(FormasPagoDto MMD)
        {
            return FormasPagoAcciones(MMD, "INSERT");
        }

        public DataSet Update(FormasPagoDto MMD)
        {
            return FormasPagoAcciones(MMD, "UPDATE");
        }

        public async Task<bool> Delete(int Id)
        {
            throw new NotImplementedException();
        }

        private DataSet FormasPagoAcciones(FormasPagoDto dto, string operacion)
        {
            DataSet result = new DataSet();

            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_FORMAS_PAGO", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    command.Parameters.Add("@OPERACION", SqlDbType.VarChar, 10).Value = operacion;

                    if (dto.iD_FORMA_PAGO.HasValue)
                        command.Parameters.Add("@ID_FORMA_PAGO", SqlDbType.Decimal).Value = dto.iD_FORMA_PAGO.Value;

                    if (dto.forma_PAGO != null)
                        command.Parameters.Add("@FORMA_PAGO", SqlDbType.VarChar, 30).Value = dto.forma_PAGO;

                    if (dto.maneja_CREDITO.HasValue)
                        command.Parameters.Add("@MANEJA_CREDITO", SqlDbType.Bit).Value = dto.maneja_CREDITO.Value;

                    if (dto.biT_CAJA.HasValue)
                        command.Parameters.Add("@BIT_CAJA", SqlDbType.Bit).Value = dto.biT_CAJA.Value;

                    if (dto.estado.HasValue)
                        command.Parameters.Add("@ESTADO", SqlDbType.Bit).Value = dto.estado.Value;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(result);
                }
            }

            return result;
        }

    }
}
