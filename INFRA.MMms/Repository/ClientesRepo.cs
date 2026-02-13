using CORE.MMms.DTOs;
using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using INFRA.MMms.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System.Data;

namespace INFRA.MMms.Repository
{
    public class ClientsRepo : IClients
    {
        private readonly MotoMastersDbContext _context;
        public ClientsRepo(MotoMastersDbContext context)
        {
            _context = context;
        }

        public async Task<DataTable> GetClients()
        {
            ClienteDTOs cli = new();
            cli.clientE_ID = null;

            DataTable MMD = ClientesAcciones(cli, "SELECCIONAR");
            return MMD;
        }

        public async Task<IEnumerable<ClientesConActividad>> getClientesConActividad()
        {
            try
            {
                var Clientes = await _context.Cliente.ToListAsync();
                List<ClientesConActividad> actividad = new();

                foreach (var cliente in Clientes)
                {
                    var totalVisitasXmesActual = await _context.Facturas.Where(x => x.IdxCliente == cliente.ClienteId && x.FechaVenta.Month == DateTime.Now.Month).ToListAsync();
                    var ultimaFecha = await _context.Facturas.Where(x => x.IdxCliente == cliente.ClienteId).OrderByDescending(x => x.FechaVenta).FirstOrDefaultAsync();

                    ClientesConActividad clientesConActividadR = new()
                    {
                        ClienteId = cliente.ClienteId,
                        Nombres = cliente.Nombres,
                        Apellidos = cliente.Apellidos,
                        NumeroTelefono = cliente.NumeroTelefono,
                        TieneVehiculo = cliente.TieneVehiculo,
                        PlacaVehiculo = cliente.PlacaVehiculo,
                        ColorVehiculo = cliente.ColorVehiculo,
                        MarcaVehiculo = cliente.MarcaVehiculo,
                        ClienteFoto = cliente.ClienteFoto,
                        ClienteRegular = cliente.ClienteRegular,
                        bitAceptaWhatsapp = cliente.bitAceptaWhatsapp,
                        bitAceptaCorreo = cliente.bitAceptaCorreo,
                        correo_electronico = cliente.correo_electronico,
                        fechaUltimaVisita = ultimaFecha?.FechaVenta
                    };

                    actividad.Add(clientesConActividadR);

                   
                }
                return actividad;
            }
            catch (Exception ex)
            {

                return null;
            }
            
        }
        public async Task<DataTable> GetxId(int Id)
        {
            ClienteDTOs cli = new();
            cli.clientE_ID = Id;
            var MMD = ClientesAcciones(cli, "SELECCIONAR");
            return MMD;
        }

        public async Task Post(ClienteDTOs MMD)
        {
            ClientesAcciones(MMD, "INSERTAR");
            return;
        }

        public async Task<bool> Update(ClienteDTOs MMD)
        {
            ClientesAcciones(MMD, "ACTUALIZAR");
            return true;
        }

        public async Task<bool> Delete(int Id)
        {
           
            int rows = await _context.SaveChangesAsync();
            return rows > 0;
        }



        public DataTable ClientesAcciones(ClienteDTOs dto, string accion)
        {
            DataTable result = new DataTable();

            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_CLIENTES_ACCIONES", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    command.Parameters.Add("@accion", SqlDbType.VarChar, 100).Value = accion;

                    if (dto.identificacion != null)
                        command.Parameters.Add("@identifacion", SqlDbType.VarChar, 100).Value = dto.identificacion;

                    if (dto.clientE_ID.HasValue)
                        command.Parameters.Add("@cliente_id", SqlDbType.Decimal).Value = dto.clientE_ID.Value;

                    if (dto.nombres != null)
                        command.Parameters.Add("@nombres", SqlDbType.VarChar, 50).Value = dto.nombres;

                    if (dto.apellidos != null)
                        command.Parameters.Add("@apellidos", SqlDbType.VarChar, 100).Value = dto.apellidos;

                    if (dto.numerO_TELEFONO != null)
                        command.Parameters.Add("@numero_tel", SqlDbType.VarChar, 15).Value = dto.numerO_TELEFONO;

                    if (dto.clientE_REGULAR.HasValue)
                        command.Parameters.Add("@cliente_regular", SqlDbType.Bit).Value = dto.clientE_REGULAR.Value;

                    if (dto.biT_PERMITE_WHATSAPP.HasValue)
                        command.Parameters.Add("@bit_permite_whatsapp", SqlDbType.Bit).Value = dto.biT_PERMITE_WHATSAPP.Value;

                    if (dto.biT_PERMITE_MAIL.HasValue)
                        command.Parameters.Add("@bit_permite_mail", SqlDbType.Bit).Value = dto.biT_PERMITE_MAIL.Value;

                    if (dto.correO_ELECTRONICO != null)
                        command.Parameters.Add("@correo_electronico", SqlDbType.VarChar, 50).Value = dto.correO_ELECTRONICO;

                    if (dto.direccioN_FISCAL != null)
                        command.Parameters.Add("@direccion_fiscal", SqlDbType.VarChar, 50).Value = dto.direccioN_FISCAL;

                    if (dto.idX_TIPO_DOCUMENTO.HasValue)
                        command.Parameters.Add("@idx_tipo_documento", SqlDbType.Decimal).Value = dto.idX_TIPO_DOCUMENTO.Value;

                    if (dto.idX_REGIMEN_TRIBUTARIO.HasValue)
                        command.Parameters.Add("@idx_regimen_tributario", SqlDbType.Decimal).Value = dto.idX_REGIMEN_TRIBUTARIO.Value;

                    if (dto.idX_RESPONSABILIDAD_FISCAL.HasValue)
                        command.Parameters.Add("@idx_responsabilidad_fiscal", SqlDbType.Decimal).Value = dto.idX_RESPONSABILIDAD_FISCAL.Value;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(result);
                }
            }

            return result;
        }

        public DataSet ConsultaFiscal(string accion)
        {
            DataSet result = new DataSet();

            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_CONSULTA_FISCAL", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;
                    command.Parameters.Add("@accion", SqlDbType.VarChar, 20).Value = accion;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(result);
                }
            }

            return result;
        }

        public DataSet ConsultaFiscalTodo()
        {
            DataSet result = new DataSet();

            using (SqlConnection connection = new SqlConnection(
                _context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_CONSULTA_FISCAL", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;
                    command.Parameters.Add("@accion", SqlDbType.VarChar, 20).Value = "todo";

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(result);
                }
            }

            return result;
        }
    }
}
