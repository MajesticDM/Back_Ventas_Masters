namespace CORE.MMms.Entidades;

public partial class Cita
{
    public decimal ApptId { get; set; }

    public decimal? IdxCliente { get; set; }

    public decimal IdxUsuarioCreador { get; set; }

    public decimal IdxServicio { get; set; }

    public decimal IdxEstados { get; set; }

    public DateTime FechaCita { get; set; }

    public virtual Cliente? IdxClienteNavigation { get; set; }

    public virtual CitasEstado IdxEstadosNavigation { get; set; } = null!;

    public virtual Servicio IdxServicioNavigation { get; set; } = null!;

    public virtual Usuario IdxUsuarioCreadorNavigation { get; set; } = null!;
}
