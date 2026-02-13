using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using INFRA.MMms.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System.Data;

namespace INFRA.MMms.Repository
{
    public class ApptsRepo : IAppts
    {
        private readonly MotoMastersDbContext _context;
        public ApptsRepo(MotoMastersDbContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<Cita>> GetAppts()
        {
            var MMD = await _context.Cita.ToListAsync();
            return MMD;
        }

        public async Task<Cita> GetxId(int Id)
        {
            var MMD = await _context.Cita.FirstOrDefaultAsync(x => x.ApptId == Id);
            return MMD;
        }

        public async Task Post(Cita MMD)
        {
            _context.Add(MMD);
            await _context.SaveChangesAsync();
        }

        public async Task<bool> Update(Cita MMD)
        {
            var dat = await GetxId((int)MMD.ApptId);

            dat.IdxCliente = MMD.IdxCliente;
            dat.IdxServicio = MMD.IdxServicio;
            dat.IdxEstados = MMD.IdxEstados;
            dat.FechaCita = MMD.FechaCita;

            int rows = await _context.SaveChangesAsync();
            return rows > 0;
        }

        public async Task<bool> Delete(int Id)
        {
            var Delete = await GetxId(Id);
            _context.Cita.Remove(Delete);

            int rows = await _context.SaveChangesAsync();
            return rows > 0;
        }

        public DataSet SelectInfoDashboard()
        {
            DataSet dashboardInfo = new DataSet();

            using (SqlConnection connection = new SqlConnection(_context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_CARGAINICIAL_DASHBOARD", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(dashboardInfo);
                }
            }
            return dashboardInfo;
        }

        public citaInformacion mostrarInformacionCitas()
        {
            citaInformacion citasInfo = new();

            citasInfo.ServicioList = [.. _context.Servicio.Where(x => x.Estados == true)];
            citasInfo.CitasEstadosList = [.. _context.CitasEstado];
            citasInfo.ClienteList = [.. _context.Cliente];

            return citasInfo;
        }

        public async Task<bool> AtenderCita(int id)
        {
            Cita cita = new Cita();
            cita = await _context.Cita.FirstOrDefaultAsync(x => x.ApptId == id);

            if (cita != null)
            {
                cita.IdxEstados = 2;

                int rows = await _context.SaveChangesAsync();
                return rows > 0;
            }
            return true;
        }
    }
}
