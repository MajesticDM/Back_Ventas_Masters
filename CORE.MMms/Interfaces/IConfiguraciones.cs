using CORE.MMms.DTOs;
using CORE.MMms.Entidades;
using System.Data;

namespace CORE.MMms.Interfaces
{
    public interface IConfiguraciones
    {
        string ModificarConfiguracionNotificaciones(string accion, decimal id_notificacion, decimal? id_servicio, decimal? id_periocidad, bool? periocidad_inmediata, bool? solo_activos, string? tipo_notificacio);
        DataSet SelectConfiguracionesNotificaciones(string accion);
        string ModificarConfiguracionGeneral(ConfiguracionGeneralDto dto);
        DataSet SeleccionarConfiguracionGeneral();
    }
}
