using CORE.MMms.DTOs;
using CORE.MMms.Entidades;
using CORE.MMms.Interfaces;
using INFRA.MMms.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System.Data;

namespace INFRA.MMms.Repository
{
    public class ConfiguracionesRepo : IConfiguraciones
    {
        private readonly MotoMastersDbContext _context;
        public ConfiguracionesRepo(MotoMastersDbContext context)
        {
            _context = context;
        }
        #region Configuración general
        public string ModificarConfiguracionGeneral(ConfiguracionGeneralDto dto)
        {
            DataSet result = new DataSet();

            using (SqlConnection connection = new SqlConnection(_context.Database.GetDbConnection().ConnectionString))
            {

                using (SqlCommand command = new SqlCommand("SP_GUARDADO_CONFIGURACION_GENERAL", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    command.Parameters.Add("@id_configuracion",        SqlDbType.Decimal).Value   = (object?)dto.id_configuracion ?? DBNull.Value;
                    command.Parameters.Add("@nombre_legal",            SqlDbType.VarChar, 1000).Value = (object?)dto.nombre_legal ?? DBNull.Value;
                    command.Parameters.Add("@nit_empresa",             SqlDbType.VarChar, 100).Value  = (object?)dto.nit_empresa ?? DBNull.Value;
                    command.Parameters.Add("@email_empresa",           SqlDbType.VarChar, 100).Value  = (object?)dto.email_empresa ?? DBNull.Value;
                    command.Parameters.Add("@direccion",               SqlDbType.VarChar, 100).Value  = (object?)dto.direccion ?? DBNull.Value;
                    command.Parameters.Add("@telefono",                SqlDbType.VarChar, 100).Value  = (object?)dto.telefono ?? DBNull.Value;
                    command.Parameters.Add("@prefijo_pais",            SqlDbType.VarChar, 100).Value  = (object?)dto.prefijo_pais ?? DBNull.Value;
                    command.Parameters.Add("@envio_whatsapp",          SqlDbType.Bit).Value           = (object?)dto.envio_whatsapp ?? DBNull.Value;
                    command.Parameters.Add("@envio_correos",           SqlDbType.Bit).Value           = (object?)dto.envio_correos ?? DBNull.Value;
                    command.Parameters.Add("@api_whatsapp",            SqlDbType.VarChar, 100).Value  = (object?)dto.api_whatsapp ?? DBNull.Value;
                    command.Parameters.Add("@token_permanente_whatsapp", SqlDbType.VarChar, 1000).Value = (object?)dto.token_permanente_whatsapp ?? DBNull.Value;
                    command.Parameters.Add("@id_telefono_whatsapp",    SqlDbType.VarChar, 100).Value  = (object?)dto.id_telefono_whatsapp ?? DBNull.Value;
                    command.Parameters.Add("@version_whatsapp",        SqlDbType.VarChar, 100).Value  = (object?)dto.version_whatsapp ?? DBNull.Value;
                    command.Parameters.Add("@porcentaje_ganancia",     SqlDbType.Decimal).Value       = (object?)dto.porcentajE_GANANCIA ?? DBNull.Value;
                    command.Parameters.Add("@ponderado",               SqlDbType.Bit).Value           = (object?)dto.biT_PONDERADO ?? DBNull.Value;
                    command.Parameters.Add("@porcentaje_iva",          SqlDbType.Decimal).Value       = (object?)dto.porcentaje_iva   ?? DBNull.Value;
                    command.Parameters.Add("@bit_iva_incluido",        SqlDbType.Bit).Value           = (object?)dto.bit_iva_incluido ?? DBNull.Value;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(result);
                }
            }
            return result.Tables[0].Rows[0]["RESPUESTA"].ToString() ?? "ERROR";
        }
        public DataSet SeleccionarConfiguracionGeneral()
        {
            DataSet ConfiguracionGeneral = new DataSet();

            using (SqlConnection connection = new SqlConnection(_context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_CARGADO_CONFIGURACION_GENERAL", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(ConfiguracionGeneral);
                }
            }
            return ConfiguracionGeneral;
        }
        #endregion

        #region Configuración de las notificaciones
        public string ModificarConfiguracionNotificaciones(string accion, decimal id_notificacion, decimal? id_servicio, decimal? id_periocidad, bool? periocidad_inmediata, bool? solo_activos, string? tipo_notificacio)
        {
            DataSet ConfiguracionNotificacion = new DataSet();

            using (SqlConnection connection = new SqlConnection(_context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_MODIFICACION_NOTIFICACIONES_CONFIGURACION", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    command.Parameters.Add(new SqlParameter("@accion", SqlDbType.VarChar)).Value = accion;
                    command.Parameters.Add(new SqlParameter("@id_notificacion", SqlDbType.Decimal)).Value = id_notificacion;
                    command.Parameters.Add(new SqlParameter("@servicio", SqlDbType.Decimal)).Value = id_servicio;
                    command.Parameters.Add(new SqlParameter("@periocidad", SqlDbType.Decimal)).Value = id_periocidad;
                    command.Parameters.Add(new SqlParameter("@periocidad_inmediata", SqlDbType.Bit)).Value = periocidad_inmediata;
                    command.Parameters.Add(new SqlParameter("@solo_activos", SqlDbType.Bit)).Value = solo_activos;
                    command.Parameters.Add(new SqlParameter("@tipo_notificacion", SqlDbType.VarChar)).Value = tipo_notificacio;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(ConfiguracionNotificacion);
                }
            }
            return ConfiguracionNotificacion.Tables[0].Rows[0]["RESULTADO"].ToString();
        }

        public DataSet SelectConfiguracionesNotificaciones(string accion)
        {
            DataSet ListaNotificaciones = new DataSet();

            using (SqlConnection connection = new SqlConnection(_context.Database.GetDbConnection().ConnectionString))
            {
                using (SqlCommand command = new SqlCommand("SP_MODIFICACION_NOTIFICACIONES_CONFIGURACION", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;
                    command.Parameters.Add(new SqlParameter("@accion", SqlDbType.VarChar)).Value = accion;

                    SqlDataAdapter adapter = new SqlDataAdapter(command);
                    adapter.Fill(ListaNotificaciones);
                }
            }
            return ListaNotificaciones;
        }
        #endregion
    }
}
